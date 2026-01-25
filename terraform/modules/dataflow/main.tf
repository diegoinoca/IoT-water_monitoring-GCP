# ============================================================================
# MÓDULO: Cloud Dataflow
# ============================================================================

variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Región de GCP"
  type        = string
}

variable "zone" {
  description = "Zona de GCP"
  type        = string
}

variable "pubsub_subscription_id" {
  description = "ID de la subscription de Pub/Sub"
  type        = string
}

variable "bigquery_dataset_id" {
  description = "ID del dataset de BigQuery"
  type        = string
}

variable "bigquery_raw_table_id" {
  description = "ID de la tabla raw de BigQuery"
  type        = string
}

variable "bigquery_agg_table_id" {
  description = "ID de la tabla de agregaciones de BigQuery"
  type        = string
}

variable "temp_bucket" {
  description = "Bucket para archivos temporales"
  type        = string
}

variable "raw_data_bucket" {
  description = "Bucket para datos raw"
  type        = string
}

variable "max_workers" {
  description = "Número máximo de workers"
  type        = number
}

variable "machine_type" {
  description = "Tipo de máquina para workers"
  type        = string
}

variable "labels" {
  description = "Labels para los recursos"
  type        = map(string)
  default     = {}
}

# ============================================================================
# SERVICE ACCOUNT para Dataflow
# ============================================================================
resource "google_service_account" "dataflow" {
  account_id   = "dataflow-pipeline-sa"
  display_name = "Service Account para Dataflow Pipeline"
  project      = var.project_id
}

# Permisos para Dataflow
resource "google_project_iam_member" "dataflow_worker" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_bigquery_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

# ============================================================================
# DATAFLOW JOB TEMPLATE
# ============================================================================

# Nota: El job de Dataflow se despliega manualmente o mediante CI/CD
# Este recurso crea un template que puede ser usado para lanzar jobs

resource "null_resource" "dataflow_pipeline_info" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Dataflow Pipeline Configuration:"
      echo "  Subscription: ${var.pubsub_subscription_id}"
      echo "  BigQuery Dataset: ${var.bigquery_dataset_id}"
      echo "  Raw Table: ${var.bigquery_raw_table_id}"
      echo "  Aggregations Table: ${var.bigquery_agg_table_id}"
      echo "  Temp Location: gs://${var.temp_bucket}/dataflow/temp"
      echo "  Staging Location: gs://${var.temp_bucket}/dataflow/staging"
      echo ""
      echo "To deploy the pipeline, run:"
      echo "  cd dataflow-pipeline"
      echo "  python pipeline.py \\"
      echo "    --project=${var.project_id} \\"
      echo "    --region=${var.region} \\"
      echo "    --runner=DataflowRunner \\"
      echo "    --subscription=projects/${var.project_id}/subscriptions/${var.pubsub_subscription_id} \\"
      echo "    --temp_location=gs://${var.temp_bucket}/dataflow/temp \\"
      echo "    --staging_location=gs://${var.temp_bucket}/dataflow/staging \\"
      echo "    --service_account_email=${google_service_account.dataflow.email}"
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "service_account_email" {
  description = "Email de la service account de Dataflow"
  value       = google_service_account.dataflow.email
}

output "temp_location" {
  description = "Ubicación de archivos temporales de Dataflow"
  value       = "gs://${var.temp_bucket}/dataflow/temp"
}

output "staging_location" {
  description = "Ubicación de staging de Dataflow"
  value       = "gs://${var.temp_bucket}/dataflow/staging"
}

output "deployment_command" {
  description = "Comando para desplegar el pipeline de Dataflow"
  value = <<-EOT
    python pipeline.py \
      --project=${var.project_id} \
      --region=${var.region} \
      --runner=DataflowRunner \
      --subscription=projects/${var.project_id}/subscriptions/${var.pubsub_subscription_id} \
      --temp_location=gs://${var.temp_bucket}/dataflow/temp \
      --staging_location=gs://${var.temp_bucket}/dataflow/staging \
      --service_account_email=${google_service_account.dataflow.email} \
      --max_num_workers=${var.max_workers} \
      --machine_type=${var.machine_type}
  EOT
}
