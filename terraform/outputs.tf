# ============================================================================
# OUTPUTS - Sistema IoT Actualizado (HTTP/Pub/Sub directo - sin IoT Core)
# ============================================================================

output "service_account_key" {
  description = "Service Account Key para dispositivos IoT en formato JSON (MANTENER SECRETO)"
  value       = base64decode(google_service_account_key.iot_devices.private_key)
  sensitive   = true
}

output "service_account_key_base64" {
  description = "Service Account Key en base64 para usar en dispositivos IoT"
  value       = google_service_account_key.iot_devices.private_key
  sensitive   = true
}

output "api_key_iot_devices" {
  description = "API Key para dispositivos IoT (DEPRECADO - usar service_account_key)"
  value       = google_apikeys_key.iot_devices.key_string
  sensitive   = true
}

output "api_key_iot_devices_id" {
  description = "ID de la API Key"
  value       = google_apikeys_key.iot_devices.id
}

output "pubsub_publish_url" {
  description = "URL para publicar mensajes vía HTTP"
  value       = "https://pubsub.googleapis.com/v1/projects/${var.project_id}/topics/${module.pubsub.telemetry_topic_name}:publish"
}

output "service_account_email" {
  description = "Email de la service account de IoT"
  value       = google_service_account.iot_devices.email
}

output "telemetry_topic_id" {
  description = "ID del topic de telemetría"
  value       = module.pubsub.telemetry_topic_id
}

output "telemetry_topic_name" {
  description = "Nombre del topic de telemetría"
  value       = module.pubsub.telemetry_topic_name
}

output "alerts_topic_id" {
  description = "ID del topic de alertas"
  value       = module.pubsub.alerts_topic_id
}

output "alerts_topic_name" {
  description = "Nombre del topic de alertas"
  value       = module.pubsub.alerts_topic_name
}

output "telemetry_subscription_id" {
  description = "ID de la suscripción a telemetría"
  value       = module.pubsub.telemetry_subscription_id
}

output "bigquery_dataset_id" {
  description = "ID del dataset de BigQuery"
  value       = module.bigquery.dataset_id
}

output "bigquery_raw_table_id" {
  description = "ID de la tabla de datos raw"
  value       = module.bigquery.raw_readings_table_id
}

output "bigquery_aggregations_minute_table_id" {
  description = "ID de la tabla de agregaciones por minuto"
  value       = module.bigquery.aggregations_minute_table_id
}

output "bigquery_aggregations_hour_table_id" {
  description = "ID de la tabla de agregaciones por hora"
  value       = module.bigquery.aggregations_hour_table_id
}

output "raw_data_bucket_name" {
  description = "Nombre del bucket para datos raw"
  value       = module.storage.raw_data_bucket_name
}

output "raw_data_bucket_url" {
  description = "URL del bucket para datos raw"
  value       = module.storage.raw_data_bucket_url
}

output "temp_bucket_name" {
  description = "Nombre del bucket temporal"
  value       = module.storage.temp_bucket_name
}

output "dataflow_service_account_email" {
  description = "Email de la service account de Dataflow"
  value       = module.dataflow.service_account_email
}

output "alert_processor_function_url" {
  description = "URL de la Cloud Function de procesamiento de alertas"
  value       = module.cloud_functions.alert_processor_url
}

output "realtime_updater_function_url" {
  description = "URL de la Cloud Function de actualización en tiempo real"
  value       = module.cloud_functions.realtime_updater_url
}
output "iot_http_proxy_url" {
  description = "URL del proxy HTTP para dispositivos IoT Arduino/ESP32"
  value       = module.cloud_functions.iot_proxy_url
}
output "project_id" {
  description = "ID del proyecto GCP"
  value       = var.project_id
}

output "region" {
  description = "Región principal"
  value       = var.region
}

output "deployment_summary" {
  description = "Resumen del despliegue"
  value = {
    project_id           = var.project_id
    region               = var.region
    environment          = var.environment
    telemetry_topic      = module.pubsub.telemetry_topic_name
    alerts_topic         = module.pubsub.alerts_topic_name
    bigquery_dataset     = module.bigquery.dataset_id
    raw_data_bucket      = module.storage.raw_data_bucket_name
    monitoring_enabled   = var.enable_cloud_monitoring
    logging_enabled      = var.enable_cloud_logging
  }
}

# Instrucciones post-deployment
output "next_steps" {
  description = "Siguientes pasos después del deployment"
  value = <<-EOT
  
  Despliegue completado exitosamente!
  
  API Key generada (guárdarla de forma segura):
    terraform output -raw api_key_iot_devices
  
  URL de publicación Pub/Sub:
    ${local.pubsub_url}
  
  Siguientes pasos:
  
  1. Configurar Arduino con API Key:
     Ver arduino-code/README.md
  
  2. Desplegar pipeline de Dataflow:
     cd ../dataflow-pipeline
     python pipeline.py \
       --project=${var.project_id} \
       --region=${var.region} \
       --subscription=${module.pubsub.telemetry_subscription_id}
  
  3. Verificar datos en BigQuery:
     bq query --use_legacy_sql=false \
       'SELECT * FROM `${var.project_id}.${module.bigquery.dataset_id}.raw_readings` LIMIT 10'
  
  4. Acceder a Cloud Console:
     BigQuery: https://console.cloud.google.com/bigquery?project=${var.project_id}
     Pub/Sub: https://console.cloud.google.com/cloudpubsub/topic/list?project=${var.project_id}
     Dataflow: https://console.cloud.google.com/dataflow/jobs?project=${var.project_id}
  
  EOT
}

locals {
  pubsub_url = "https://pubsub.googleapis.com/v1/projects/${var.project_id}/topics/${module.pubsub.telemetry_topic_name}:publish"
}
