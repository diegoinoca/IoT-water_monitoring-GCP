# ============================================================================
# MÓDULO: Cloud Functions
# ============================================================================

variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Región de GCP"
  type        = string
}

variable "alerts_topic_id" {
  description = "ID del topic de alertas"
  type        = string
}

variable "telemetry_topic_id" {
  description = "ID del topic de telemetría"
  type        = string
}

variable "temp_bucket" {
  description = "Bucket para código fuente de las funciones"
  type        = string
}

variable "alert_email_recipients" {
  description = "Lista de emails para alertas"
  type        = list(string)
}

variable "sendgrid_api_key" {
  description = "API key de SendGrid"
  type        = string
  sensitive   = true
}

variable "temperature_threshold_high" {
  description = "Umbral alto de temperatura"
  type        = number
}

variable "temperature_threshold_low" {
  description = "Umbral bajo de temperatura"
  type        = number
}

variable "humidity_threshold_high" {
  description = "Umbral alto de humedad"
  type        = number
}

variable "humidity_threshold_low" {
  description = "Umbral bajo de humedad"
  type        = number
}

variable "iot_api_key" {
  description = "API Key para dispositivos IoT"
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels para los recursos"
  type        = map(string)
  default     = {}
}

# ============================================================================
# SERVICE ACCOUNT para Cloud Functions
# ============================================================================
resource "google_service_account" "cloud_functions" {
  account_id   = "cloud-functions-sa"
  display_name = "Service Account para Cloud Functions"
  project      = var.project_id
}

# Permisos para Cloud Functions
resource "google_project_iam_member" "functions_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloud_functions.email}"
}

resource "google_project_iam_member" "functions_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_functions.email}"
}

resource "google_project_iam_member" "functions_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_functions.email}"
}

# ============================================================================
# CLOUD FUNCTION: IoT HTTP Proxy (para dispositivos Arduino/ESP32)
# ============================================================================

# Comprimir el código de la función
data "archive_file" "iot_proxy_source" {
  type        = "zip"
  source_dir  = "${path.module}/../../../cloud-functions/iot-http-proxy"
  output_path = "${path.module}/tmp/iot-http-proxy.zip"
}

# Subir el código al bucket
resource "google_storage_bucket_object" "iot_proxy_source" {
  name   = "cloud-functions/iot-http-proxy-${data.archive_file.iot_proxy_source.output_md5}.zip"
  bucket = var.temp_bucket
  source = data.archive_file.iot_proxy_source.output_path
}

# Crear Cloud Function
resource "google_cloudfunctions2_function" "iot_proxy" {
  name     = "iot-http-proxy"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "python311"
    entry_point = "iot_telemetry"
    
    source {
      storage_source {
        bucket = var.temp_bucket
        object = google_storage_bucket_object.iot_proxy_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.cloud_functions.email

    environment_variables = {
      GCP_PROJECT  = var.project_id
      PUBSUB_TOPIC = "sensor-telemetry"
      IOT_API_KEY  = var.iot_api_key
    }
  }

  labels = var.labels
}

# Permitir invocación pública (sin autenticación)
resource "google_cloud_run_service_iam_member" "iot_proxy_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.iot_proxy.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ============================================================================
# CLOUD FUNCTION: Alert Processor
# ============================================================================

# Comprimir el código de la función
data "archive_file" "alert_processor_source" {
  type        = "zip"
  source_dir  = "${path.module}/../../../cloud-functions/alert-processor"
  output_path = "${path.module}/tmp/alert-processor.zip"
}

# Subir el código a Cloud Storage
resource "google_storage_bucket_object" "alert_processor_source" {
  name   = "cloud-functions/alert-processor-${data.archive_file.alert_processor_source.output_md5}.zip"
  bucket = var.temp_bucket
  source = data.archive_file.alert_processor_source.output_path
}

# Cloud Function para procesamiento de alertas
resource "google_cloudfunctions2_function" "alert_processor" {
  name     = "alert-processor"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "python311"
    entry_point = "process_alert"
    
    source {
      storage_source {
        bucket = var.temp_bucket
        object = google_storage_bucket_object.alert_processor_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 100
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.cloud_functions.email

    environment_variables = {
      TEMPERATURE_THRESHOLD_HIGH = var.temperature_threshold_high
      TEMPERATURE_THRESHOLD_LOW  = var.temperature_threshold_low
      HUMIDITY_THRESHOLD_HIGH    = var.humidity_threshold_high
      HUMIDITY_THRESHOLD_LOW     = var.humidity_threshold_low
      ALERT_TOPIC_ID             = var.alerts_topic_id
      PROJECT_ID                 = var.project_id
    }

    secret_environment_variables {
      key        = "SENDGRID_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.sendgrid_api_key.secret_id
      version    = "latest"
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.telemetry_topic_id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.cloud_functions.email
  }

  labels = var.labels
}

# Permitir que Pub/Sub invoque la función alert-processor
resource "google_cloud_run_service_iam_member" "alert_processor_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.alert_processor.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_functions.email}"
}

# ============================================================================
# CLOUD FUNCTION: Realtime Updater
# ============================================================================

# Comprimir el código de la función
data "archive_file" "realtime_updater_source" {
  type        = "zip"
  source_dir  = "${path.module}/../../../cloud-functions/realtime-updater"
  output_path = "${path.module}/tmp/realtime-updater.zip"
}

# Subir el código a Cloud Storage
resource "google_storage_bucket_object" "realtime_updater_source" {
  name   = "cloud-functions/realtime-updater-${data.archive_file.realtime_updater_source.output_md5}.zip"
  bucket = var.temp_bucket
  source = data.archive_file.realtime_updater_source.output_path
}

# Cloud Function para actualización en tiempo real
resource "google_cloudfunctions2_function" "realtime_updater" {
  name     = "realtime-updater"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "python311"
    entry_point = "update_firestore"
    
    source {
      storage_source {
        bucket = var.temp_bucket
        object = google_storage_bucket_object.realtime_updater_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 100
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 30
    service_account_email = google_service_account.cloud_functions.email

    environment_variables = {
      PROJECT_ID = var.project_id
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.telemetry_topic_id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.cloud_functions.email
  }

  labels = var.labels
}

# Permitir que Pub/Sub invoque la función realtime-updater
resource "google_cloud_run_service_iam_member" "realtime_updater_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.realtime_updater.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_functions.email}"
}

# ============================================================================
# SECRET MANAGER para SendGrid API Key
# ============================================================================
resource "google_secret_manager_secret" "sendgrid_api_key" {
  secret_id = "sendgrid-api-key"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "sendgrid_api_key" {
  secret      = google_secret_manager_secret.sendgrid_api_key.id
  secret_data = var.sendgrid_api_key != "" ? var.sendgrid_api_key : "placeholder"
}

# Permitir que Cloud Functions acceda al secreto
resource "google_secret_manager_secret_iam_member" "functions_secret_accessor" {
  secret_id = google_secret_manager_secret.sendgrid_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_functions.email}"
  project   = var.project_id
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "iot_proxy_url" {
  description = "URL de la función iot-http-proxy para Arduino"
  value       = google_cloudfunctions2_function.iot_proxy.service_config[0].uri
}

output "alert_processor_url" {
  description = "URL de la función alert-processor"
  value       = google_cloudfunctions2_function.alert_processor.service_config[0].uri
}

output "realtime_updater_url" {
  description = "URL de la función realtime-updater"
  value       = google_cloudfunctions2_function.realtime_updater.service_config[0].uri
}

output "service_account_email" {
  description = "Email de la service account de Cloud Functions"
  value       = google_service_account.cloud_functions.email
}
