# ============================================================================
# MÓDULO: Cloud Storage Buckets
# ============================================================================

variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Región de GCP"
  type        = string
}

variable "raw_data_bucket" {
  description = "Nombre del bucket para datos raw"
  type        = string
}

variable "temp_bucket" {
  description = "Nombre del bucket para archivos temporales"
  type        = string
}

variable "labels" {
  description = "Labels para los recursos"
  type        = map(string)
  default     = {}
}

# ============================================================================
# BUCKET: Raw Data Backup
# ============================================================================
resource "google_storage_bucket" "raw_data" {
  name          = var.raw_data_bucket
  location      = var.region
  project       = var.project_id
  labels        = var.labels
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90 # días
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365 # días
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age                = 730 # días (2 años)
      with_state         = "ARCHIVED"
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# ============================================================================
# BUCKET: Temporary Files (Dataflow, Cloud Functions)
# ============================================================================
resource "google_storage_bucket" "temp" {
  name          = var.temp_bucket
  location      = var.region
  project       = var.project_id
  labels        = merge(var.labels, { purpose = "temporary" })
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 7 # días
    }
    action {
      type = "Delete"
    }
  }
}

# ============================================================================
# IAM: Permisos
# ============================================================================

# Permitir que Dataflow escriba en el bucket raw_data
resource "google_storage_bucket_iam_member" "raw_data_dataflow_writer" {
  bucket = google_storage_bucket.raw_data.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:service-${data.google_project.project.number}@dataflow-service-producer-prod.iam.gserviceaccount.com"
}

# Permitir que Dataflow lea/escriba en el bucket temporal
resource "google_storage_bucket_iam_member" "temp_dataflow_admin" {
  bucket = google_storage_bucket.temp.name
  role   = "roles/storage.admin"
  member = "serviceAccount:service-${data.google_project.project.number}@dataflow-service-producer-prod.iam.gserviceaccount.com"
}

# Data source para información del proyecto
data "google_project" "project" {
  project_id = var.project_id
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "raw_data_bucket_name" {
  description = "Nombre del bucket de datos raw"
  value       = google_storage_bucket.raw_data.name
}

output "raw_data_bucket_url" {
  description = "URL del bucket de datos raw"
  value       = google_storage_bucket.raw_data.url
}

output "temp_bucket_name" {
  description = "Nombre del bucket temporal"
  value       = google_storage_bucket.temp.name
}

output "temp_bucket_url" {
  description = "URL del bucket temporal"
  value       = google_storage_bucket.temp.url
}
