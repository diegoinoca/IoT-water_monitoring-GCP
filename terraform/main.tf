# ============================================================================
# SISTEMA IoT DE MONITOREO DE CALIDAD DE AGUAS - CONFIGURACIÓN PRINCIPAL
# ============================================================================

# Habilitar APIs necesarias de GCP
resource "google_project_service" "required_apis" {
  for_each = toset([
    "pubsub.googleapis.com",
    "dataflow.googleapis.com",
    "bigquery.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "firestore.googleapis.com",
    "storage-api.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "apikeys.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Identificador único para recursos que requieren nombres globalmente únicos
resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================================
# Service Account para Dispositivos IoT (reemplaza IoT Core)
# ============================================================================
resource "google_service_account" "iot_devices" {
  account_id   = "iot-devices-sa"
  display_name = "Service Account for IoT Devices"
  project      = var.project_id
}

# Permisos para publicar en Pub/Sub
resource "google_project_iam_member" "iot_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.iot_devices.email}"
}

# Service Account Key para dispositivos IoT
resource "google_service_account_key" "iot_devices" {
  service_account_id = google_service_account.iot_devices.name
}

# ============================================================================
# API Key para Dispositivos IoT (DEPRECADO - usar Service Account Key)
# Se mantiene para compatibilidad, pero debe usarse la Service Account Key
# ============================================================================
resource "google_apikeys_key" "iot_devices" {
  name         = "iot-devices-pubsub-key-${random_id.suffix.hex}"
  display_name = "API Key for IoT Devices - Pub/Sub Access"
  project      = var.project_id

  restrictions {
    api_targets {
      service = "pubsub.googleapis.com"
    }
  }

  depends_on = [
    google_project_service.required_apis
  ]
}

# ============================================================================
# MÓDULO: Cloud Pub/Sub
# ============================================================================
module "pubsub" {
  source = "./modules/pubsub"

  project_id               = var.project_id
  telemetry_topic_name     = var.pubsub_topic_name
  alerts_topic_name        = var.pubsub_alerts_topic_name
  labels                   = var.labels

  depends_on = [google_project_service.required_apis]
}

# ============================================================================
# MÓDULO: Cloud Storage
# ============================================================================
module "storage" {
  source = "./modules/storage"

  project_id          = var.project_id
  region              = var.region
  raw_data_bucket     = var.storage_bucket_name
  temp_bucket         = var.dataflow_temp_bucket_name
  labels              = var.labels

  depends_on = [google_project_service.required_apis]
}

# ============================================================================
# MÓDULO: BigQuery
# ============================================================================
module "bigquery" {
  source = "./modules/bigquery"

  project_id                    = var.project_id
  region                        = var.region
  dataset_name                  = var.bigquery_dataset_name
  retention_days_raw            = var.retention_days_raw_data
  retention_days_aggregated     = var.retention_days_aggregated_data
  labels                        = var.labels

  depends_on = [google_project_service.required_apis]
}

# ============================================================================
# MÓDULO: Firestore
# ============================================================================
module "firestore" {
  source = "./modules/firestore"

  project_id  = var.project_id
  location    = var.firestore_location
  labels      = var.labels

  depends_on = [google_project_service.required_apis]
}

# ============================================================================
# MÓDULO: Cloud Functions
# ============================================================================
module "cloud_functions" {
  source = "./modules/cloud-functions"

  project_id                     = var.project_id
  region                         = var.region
  alerts_topic_id                = module.pubsub.alerts_topic_id
  telemetry_topic_id             = module.pubsub.telemetry_topic_id
  temp_bucket                    = module.storage.temp_bucket_name
  alert_email_recipients         = var.alert_email_recipients
  sendgrid_api_key              = var.sendgrid_api_key
  temperature_threshold_high     = var.alert_temperature_threshold_high
  temperature_threshold_low      = var.alert_temperature_threshold_low
  humidity_threshold_high        = var.alert_humidity_threshold_high
  humidity_threshold_low         = var.alert_humidity_threshold_low
  iot_api_key                   = google_apikeys_key.iot_devices.key_string
  labels                         = var.labels

  depends_on = [
    google_project_service.required_apis,
    module.pubsub,
    module.storage
  ]
}

# ============================================================================
# MÓDULO: Cloud Dataflow
# ============================================================================
module "dataflow" {
  source = "./modules/dataflow"

  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  pubsub_subscription_id  = module.pubsub.telemetry_subscription_id
  bigquery_dataset_id     = module.bigquery.dataset_id
  bigquery_raw_table_id   = module.bigquery.raw_readings_table_id
  bigquery_agg_table_id   = module.bigquery.aggregations_minute_table_id
  temp_bucket             = module.storage.temp_bucket_name
  raw_data_bucket         = module.storage.raw_data_bucket_name
  max_workers             = var.dataflow_max_workers
  machine_type            = var.dataflow_machine_type
  labels                  = var.labels

  depends_on = [
    google_project_service.required_apis,
    module.pubsub,
    module.bigquery,
    module.storage
  ]
}

# ============================================================================
# MONITOREO Y LOGGING
# ============================================================================

# Log sink para almacenar logs de IoT Core en BigQuery
resource "google_logging_project_sink" "iot_logs" {
  count = var.enable_cloud_logging ? 1 : 0

  name        = "iot-telemetry-logs"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${module.bigquery.dataset_id}"
  filter      = "resource.type=\"cloudiot_device\""

  unique_writer_identity = true

  depends_on = [module.bigquery]
}

# Otorgar permisos al log sink para escribir en BigQuery
resource "google_bigquery_dataset_iam_member" "log_sink_writer" {
  count = var.enable_cloud_logging ? 1 : 0

  dataset_id = module.bigquery.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.iot_logs[0].writer_identity

  depends_on = [google_logging_project_sink.iot_logs]
}

# Dashboard de Cloud Monitoring
resource "google_monitoring_dashboard" "iot_dashboard" {
  count = var.enable_cloud_monitoring ? 1 : 0

  dashboard_json = jsonencode({
    displayName = "IoT Water Quality Monitoring Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Mensajes Pub/Sub por Minuto"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" resource.type=\"pubsub_topic\" resource.label.topic_id=\"${var.pubsub_topic_name}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Alertas Generadas"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" resource.type=\"pubsub_topic\" resource.label.topic_id=\"sensor-alerts\""
                    aggregation = {
                      alignmentPeriod  = "300s"
                      perSeriesAligner = "ALIGN_SUM"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}

# Alerta para errores de Dataflow
resource "google_monitoring_alert_policy" "dataflow_errors" {
  count = var.enable_cloud_monitoring ? 1 : 0

  display_name = "Dataflow Job Errors"
  combiner     = "OR"

  conditions {
    display_name = "Error rate too high"
    condition_threshold {
      filter          = "resource.type=\"dataflow_job\" AND metric.type=\"dataflow.googleapis.com/job/element_count\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = []
  
  alert_strategy {
    auto_close = "1800s"
  }
}
