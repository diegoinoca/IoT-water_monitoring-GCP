# ============================================================================
# MÓDULO: Firestore Database
# ============================================================================

variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "location" {
  description = "Ubicación de Firestore"
  type        = string
}

variable "labels" {
  description = "Labels para los recursos"
  type        = map(string)
  default     = {}
}

# ============================================================================
# FIRESTORE DATABASE
# ============================================================================
resource "google_firestore_database" "database" {
  project     = var.project_id
  name        = "(default)"
  location_id = "nam5"
  type        = "FIRESTORE_NATIVE"

  concurrency_mode = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
  deletion_policy = "DELETE" 
}

# ============================================================================
# FIRESTORE INDEXES
# ============================================================================

# Index para consultar dispositivos por ubicación y timestamp
resource "google_firestore_index" "device_location_timestamp" {
  project    = var.project_id
  database   = google_firestore_database.database.name
  collection = "devices"

  fields {
    field_path = "location"
    order      = "ASCENDING"
  }

  fields {
    field_path = "last_reading_timestamp"
    order      = "DESCENDING"
  }

  depends_on = [google_firestore_database.database]
}

# Index para consultar lecturas actuales por dispositivo
resource "google_firestore_index" "current_readings_device" {
  project    = var.project_id
  database   = google_firestore_database.database.name
  collection = "current_readings"

  fields {
    field_path = "device_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }

  depends_on = [google_firestore_database.database]
}

# Index para consultar alertas por severidad y timestamp
resource "google_firestore_index" "alerts_severity_timestamp" {
  project    = var.project_id
  database   = google_firestore_database.database.name
  collection = "alerts"

  fields {
    field_path = "severity"
    order      = "ASCENDING"
  }

  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }

  depends_on = [google_firestore_database.database]
}

# Index para consultar alertas activas por dispositivo
resource "google_firestore_index" "alerts_device_active" {
  project    = var.project_id
  database   = google_firestore_database.database.name
  collection = "alerts"

  fields {
    field_path = "device_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "is_active"
    order      = "ASCENDING"
  }

  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }

  depends_on = [google_firestore_database.database]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "database_id" {
  description = "ID de la base de datos Firestore"
  value       = google_firestore_database.database.id
}

output "database_name" {
  description = "Nombre de la base de datos Firestore"
  value       = google_firestore_database.database.name
}

output "database_location" {
  description = "Ubicación de la base de datos Firestore"
  value       = google_firestore_database.database.location_id
}
