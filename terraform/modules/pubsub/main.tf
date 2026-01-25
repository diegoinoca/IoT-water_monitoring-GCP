# ============================================================================
# MÓDULO: Cloud Pub/Sub Topics y Subscriptions
# ============================================================================

variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "telemetry_topic_name" {
  description = "Nombre del topic de telemetría"
  type        = string
}

variable "alerts_topic_name" {
  description = "Nombre del topic de alertas"
  type        = string
}

variable "labels" {
  description = "Labels para los recursos"
  type        = map(string)
  default     = {}
}

# ============================================================================
# TOPIC: Telemetría de Sensores
# ============================================================================
resource "google_pubsub_topic" "telemetry" {
  name    = var.telemetry_topic_name
  project = var.project_id
  labels  = var.labels

  message_retention_duration = "86400s" # 24 horas
  
  message_storage_policy {
    allowed_persistence_regions = []  # Todas las regiones
  }
}

# Subscription para Dataflow
resource "google_pubsub_subscription" "telemetry_dataflow" {
  name    = "${var.telemetry_topic_name}-dataflow-sub"
  topic   = google_pubsub_topic.telemetry.id
  project = var.project_id
  labels  = var.labels

  # Configuración de acknowledgment
  ack_deadline_seconds = 60

  # Configuración de retry
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # Configuración de dead letter
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  # Configuración de expiración
  expiration_policy {
    ttl = "" # No expira
  }

  message_retention_duration = "604800s" # 7 días

  enable_message_ordering = false
}

# Subscription para Cloud Functions (procesamiento de alertas)
resource "google_pubsub_subscription" "telemetry_functions" {
  name    = "${var.telemetry_topic_name}-functions-sub"
  topic   = google_pubsub_topic.telemetry.id
  project = var.project_id
  labels  = var.labels

  ack_deadline_seconds = 30

  retry_policy {
    minimum_backoff = "5s"
    maximum_backoff = "300s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  message_retention_duration = "604800s" # 7 días
}

# ============================================================================
# TOPIC: Alertas
# ============================================================================
resource "google_pubsub_topic" "alerts" {
  name    = var.alerts_topic_name
  project = var.project_id
  labels  = var.labels

  message_retention_duration = "259200s" # 3 días
}

# Subscription para notificaciones de alertas
resource "google_pubsub_subscription" "alerts_notifications" {
  name    = "${var.alerts_topic_name}-notifications-sub"
  topic   = google_pubsub_topic.alerts.id
  project = var.project_id
  labels  = var.labels

  ack_deadline_seconds = 30

  push_config {
    push_endpoint = "" # Se configura después con Cloud Functions URL
  }

  message_retention_duration = "259200s" # 3 días
}

# ============================================================================
# TOPIC: Dead Letter Queue
# ============================================================================
resource "google_pubsub_topic" "dead_letter" {
  name    = "dead-letter-queue"
  project = var.project_id
  labels  = merge(var.labels, { purpose = "dead-letter" })

  message_retention_duration = "604800s" # 7 días
}

# Subscription para monitorear mensajes fallidos
resource "google_pubsub_subscription" "dead_letter_monitoring" {
  name    = "dead-letter-monitoring-sub"
  topic   = google_pubsub_topic.dead_letter.id
  project = var.project_id
  labels  = merge(var.labels, { purpose = "monitoring" })

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 días

  expiration_policy {
    ttl = "" # No expira
  }
}

# ============================================================================
# IAM: Permisos
# ============================================================================

# Permitir que Pub/Sub publique en el dead letter topic
resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Permitir que Pub/Sub consuma del dead letter topic
resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.telemetry_dataflow.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Data source para obtener información del proyecto
data "google_project" "project" {
  project_id = var.project_id
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "telemetry_topic_id" {
  description = "ID del topic de telemetría"
  value       = google_pubsub_topic.telemetry.id
}

output "telemetry_topic_name" {
  description = "Nombre del topic de telemetría"
  value       = google_pubsub_topic.telemetry.name
}

output "telemetry_subscription_id" {
  description = "ID de la subscription de telemetría para Dataflow"
  value       = google_pubsub_subscription.telemetry_dataflow.id
}

output "telemetry_subscription_name" {
  description = "Nombre de la subscription de telemetría"
  value       = google_pubsub_subscription.telemetry_dataflow.name
}

output "alerts_topic_id" {
  description = "ID del topic de alertas"
  value       = google_pubsub_topic.alerts.id
}

output "alerts_topic_name" {
  description = "Nombre del topic de alertas"
  value       = google_pubsub_topic.alerts.name
}

output "alerts_subscription_id" {
  description = "ID de la subscription de alertas"
  value       = google_pubsub_subscription.alerts_notifications.id
}

output "dead_letter_topic_id" {
  description = "ID del topic dead letter"
  value       = google_pubsub_topic.dead_letter.id
}

output "dead_letter_topic_name" {
  description = "Nombre del topic dead letter"
  value       = google_pubsub_topic.dead_letter.name
}
