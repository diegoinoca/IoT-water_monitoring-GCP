variable "project_id" {
  description = "ID del proyecto de Google Cloud Platform"
  type        = string
}

variable "region" {
  description = "Región principal de GCP para los recursos"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona de GCP para recursos zonales"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "iot_registry_name" {
  description = "Nombre del registry de IoT Core"
  type        = string
  default     = "water-quality-sensors"
}

variable "pubsub_topic_name" {
  description = "Nombre del topic principal de Pub/Sub"
  type        = string
  default     = "sensor-telemetry"
}

variable "pubsub_alerts_topic_name" {
  description = "Nombre del topic de alertas de Pub/Sub"
  type        = string
  default     = "sensor-alerts"
}

variable "bigquery_dataset_name" {
  description = "Nombre del dataset de BigQuery"
  type        = string
  default     = "sensor_data"
}

variable "storage_bucket_name" {
  description = "Nombre del bucket de Cloud Storage (debe ser globalmente único)"
  type        = string
}

variable "dataflow_temp_bucket_name" {
  description = "Nombre del bucket para archivos temporales de Dataflow"
  type        = string
}

variable "firestore_location" {
  description = "Ubicación para Firestore"
  type        = string
  default     = "us-central"
}

variable "sensor_reading_frequency_seconds" {
  description = "Frecuencia de lectura de sensores en segundos"
  type        = number
  default     = 30
}

variable "alert_temperature_threshold_high" {
  description = "Umbral alto de temperatura para alertas (°C)"
  type        = number
  default     = 30
}

variable "alert_temperature_threshold_low" {
  description = "Umbral bajo de temperatura para alertas (°C)"
  type        = number
  default     = 5
}

variable "alert_humidity_threshold_high" {
  description = "Umbral alto de humedad para alertas (%)"
  type        = number
  default     = 80
}

variable "alert_humidity_threshold_low" {
  description = "Umbral bajo de humedad para alertas (%)"
  type        = number
  default     = 20
}

variable "alert_email_recipients" {
  description = "Lista de emails para recibir alertas"
  type        = list(string)
  default     = []
}

variable "sendgrid_api_key" {
  description = "API key de SendGrid para envío de emails"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dataflow_max_workers" {
  description = "Número máximo de workers para Dataflow"
  type        = number
  default     = 10
}

variable "dataflow_machine_type" {
  description = "Tipo de máquina para workers de Dataflow"
  type        = string
  default     = "n1-standard-2"
}

variable "enable_cloud_monitoring" {
  description = "Habilitar Cloud Monitoring y alertas"
  type        = bool
  default     = true
}

variable "enable_cloud_logging" {
  description = "Habilitar Cloud Logging"
  type        = bool
  default     = true
}

variable "retention_days_raw_data" {
  description = "Días de retención para datos raw en BigQuery"
  type        = number
  default     = 365
}

variable "retention_days_aggregated_data" {
  description = "Días de retención para datos agregados en BigQuery"
  type        = number
  default     = 730
}

variable "labels" {
  description = "Labels comunes para todos los recursos"
  type        = map(string)
  default = {
    project     = "water-quality-monitoring"
    managed-by  = "terraform"
    team        = "data-engineering"
  }
}
