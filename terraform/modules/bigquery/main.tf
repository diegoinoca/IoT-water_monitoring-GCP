# ============================================================================
# MÓDULO: BigQuery Dataset y Tablas
# ============================================================================

variable "project_id" {
  description = "ID del proyecto GCP"
  type        = string
}

variable "region" {
  description = "Región de GCP"
  type        = string
}

variable "dataset_name" {
  description = "Nombre del dataset de BigQuery"
  type        = string
}

variable "retention_days_raw" {
  description = "Días de retención para datos raw"
  type        = number
  default     = 365
}

variable "retention_days_aggregated" {
  description = "Días de retención para datos agregados"
  type        = number
  default     = 730
}

variable "labels" {
  description = "Labels para los recursos"
  type        = map(string)
  default     = {}
}

# ============================================================================
# DATASET
# ============================================================================
resource "google_bigquery_dataset" "sensor_data" {
  dataset_id    = var.dataset_name
  project       = var.project_id
  friendly_name = "Sensor Water Quality Data"
  description   = "Dataset para almacenar datos de sensores de calidad de agua"
  location      = var.region
  labels        = var.labels

  default_table_expiration_ms = null # No expira automáticamente

  access {
    role          = "OWNER"
    user_by_email = "${data.google_project.project.number}@cloudservices.gserviceaccount.com"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }
}

# ============================================================================
# TABLA: Raw Readings (Datos Raw de Sensores)
# ============================================================================
resource "google_bigquery_table" "raw_readings" {
  deletion_protection = false
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "raw_readings"
  project    = var.project_id
  labels     = var.labels
  

  description = "Tabla con datos raw de lecturas de sensores"

  # Particionamiento por timestamp (diario)
  time_partitioning {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = var.retention_days_raw * 24 * 60 * 60 * 1000
  }

  # Clustering por device_id y location
  clustering = ["device_id", "location"]

  schema = jsonencode([
    {
      name        = "device_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "ID único del dispositivo IoT"
    },
    {
      name        = "timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Timestamp de la lectura"
    },
    {
      name        = "temperature"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Temperatura en grados Celsius"
    },
    {
      name        = "humidity"
      type        = "FLOAT"
      mode        = "REQUIRED"
      description = "Humedad relativa en porcentaje"
    },
    {
      name        = "location"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Ubicación geográfica del sensor"
    },
    {
      name        = "latitude"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Latitud GPS"
    },
    {
      name        = "longitude"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Longitud GPS"
    },
    {
      name        = "water_quality_index"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Índice calculado de calidad de agua"
    },
    {
      name        = "metadata"
      type        = "JSON"
      mode        = "NULLABLE"
      description = "Metadatos adicionales del sensor"
    },
    {
      name        = "ingestion_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Timestamp de ingesta en el sistema"
    }
  ])
}

# ============================================================================
# TABLA: Aggregations Minute (Agregaciones por Minuto)
# ============================================================================
resource "google_bigquery_table" "aggregations_minute" {
  deletion_protection = false
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "aggregations_minute"
  project    = var.project_id
  labels     = var.labels
  

  description = "Agregaciones de datos por ventanas de 1 minuto"

  time_partitioning {
    type          = "DAY"
    field         = "window_start"
    expiration_ms = var.retention_days_aggregated * 24 * 60 * 60 * 1000
  }

  clustering = ["device_id", "location"]

  schema = jsonencode([
    {
      name        = "device_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "ID del dispositivo"
    },
    {
      name        = "window_start"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Inicio de la ventana de tiempo"
    },
    {
      name        = "window_end"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Fin de la ventana de tiempo"
    },
    {
      name        = "location"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Ubicación del sensor"
    },
    {
      name        = "avg_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Temperatura promedio"
    },
    {
      name        = "min_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Temperatura mínima"
    },
    {
      name        = "max_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Temperatura máxima"
    },
    {
      name        = "avg_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Humedad promedio"
    },
    {
      name        = "min_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Humedad mínima"
    },
    {
      name        = "max_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Humedad máxima"
    },
    {
      name        = "reading_count"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Número de lecturas en la ventana"
    },
    {
      name        = "processing_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Timestamp de procesamiento"
    }
  ])
}

# ============================================================================
# TABLA: Aggregations Hour (Agregaciones por Hora)
# ============================================================================
resource "google_bigquery_table" "aggregations_hour" {
  deletion_protection = false
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "aggregations_hour"
  project    = var.project_id
  labels     = var.labels  
  description = "Agregaciones de datos por ventanas de 1 hora"

  time_partitioning {
    type          = "DAY"
    field         = "window_start"
    expiration_ms = var.retention_days_aggregated * 24 * 60 * 60 * 1000
  }

  clustering = ["device_id", "location"]

  schema = jsonencode([
    {
      name        = "device_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "ID del dispositivo"
    },
    {
      name        = "window_start"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Inicio de la ventana de tiempo"
    },
    {
      name        = "window_end"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Fin de la ventana de tiempo"
    },
    {
      name        = "location"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Ubicación del sensor"
    },
    {
      name        = "avg_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Temperatura promedio"
    },
    {
      name        = "min_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Temperatura mínima"
    },
    {
      name        = "max_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Temperatura máxima"
    },
    {
      name        = "std_temperature"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Desviación estándar de temperatura"
    },
    {
      name        = "avg_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Humedad promedio"
    },
    {
      name        = "min_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Humedad mínima"
    },
    {
      name        = "max_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Humedad máxima"
    },
    {
      name        = "std_humidity"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Desviación estándar de humedad"
    },
    {
      name        = "reading_count"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Número de lecturas en la ventana"
    },
    {
      name        = "processing_timestamp"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Timestamp de procesamiento"
    }
  ])
}

# ============================================================================
# VISTA: Latest Readings (Últimas Lecturas por Dispositivo)
# ============================================================================
resource "google_bigquery_table" "latest_readings_view" {
  deletion_protection = false
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "latest_readings"
  project    = var.project_id
  labels     = var.labels
  

  description = "Vista con las últimas lecturas de cada dispositivo"
  
  depends_on = [
    google_bigquery_table.raw_readings
  ]

  view {
    query = <<-SQL
      SELECT 
        device_id,
        timestamp,
        temperature,
        humidity,
        location,
        latitude,
        longitude,
        water_quality_index,
        ingestion_timestamp
      FROM (
        SELECT *,
          ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY timestamp DESC) as rn
        FROM `${var.project_id}.${var.dataset_name}.raw_readings`
        WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      )
      WHERE rn = 1
    SQL
    use_legacy_sql = false
  }
}

# ============================================================================
# VISTA: Hourly Statistics (Estadísticas Horarias)
# ============================================================================
resource "google_bigquery_table" "hourly_stats_view" {
  deletion_protection = false
  dataset_id = google_bigquery_dataset.sensor_data.dataset_id
  table_id   = "hourly_statistics"
  project    = var.project_id
  labels     = var.labels  
  description = "Vista con estadísticas horarias agregadas"
  
  depends_on = [
    google_bigquery_table.raw_readings
  ]

  view {
    query = <<-SQL
      SELECT 
        device_id,
        location,
        TIMESTAMP_TRUNC(timestamp, HOUR) as hour,
        AVG(temperature) as avg_temperature,
        MIN(temperature) as min_temperature,
        MAX(temperature) as max_temperature,
        AVG(humidity) as avg_humidity,
        MIN(humidity) as min_humidity,
        MAX(humidity) as max_humidity,
        COUNT(*) as reading_count
      FROM `${var.project_id}.${var.dataset_name}.raw_readings`
      WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
      GROUP BY device_id, location, hour
      ORDER BY hour DESC
    SQL
    use_legacy_sql = false
  }
}

# Data source para información del proyecto
data "google_project" "project" {
  project_id = var.project_id
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "dataset_id" {
  description = "ID del dataset"
  value       = google_bigquery_dataset.sensor_data.dataset_id
}

output "dataset_name" {
  description = "Nombre del dataset"
  value       = google_bigquery_dataset.sensor_data.friendly_name
}

output "raw_readings_table_id" {
  description = "ID de la tabla raw_readings"
  value       = google_bigquery_table.raw_readings.table_id
}

output "aggregations_minute_table_id" {
  description = "ID de la tabla aggregations_minute"
  value       = google_bigquery_table.aggregations_minute.table_id
}

output "aggregations_hour_table_id" {
  description = "ID de la tabla aggregations_hour"
  value       = google_bigquery_table.aggregations_hour.table_id
}

output "latest_readings_view_id" {
  description = "ID de la vista latest_readings"
  value       = google_bigquery_table.latest_readings_view.table_id
}

output "hourly_stats_view_id" {
  description = "ID de la vista hourly_statistics"
  value       = google_bigquery_table.hourly_stats_view.table_id
}
