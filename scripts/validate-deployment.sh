#!/bin/bash

# ============================================================================
# Script de Validación Post-Despliegue
# ============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] ${1}${NC}"; }
log_success() { echo -e "${GREEN}[OK] ${1}${NC}"; }
log_warning() { echo -e "${YELLOW}[WARNING] ${1}${NC}"; }
log_error() { echo -e "${RED}[ERROR] ${1}${NC}"; }

# Leer configuración
if [ ! -f "terraform/terraform.tfvars" ]; then
    log_error "Archivo terraform.tfvars no encontrado"
    exit 1
fi

PROJECT_ID=$(grep 'project_id' terraform/terraform.tfvars | cut -d '"' -f 2)
REGION=$(grep 'region' terraform/terraform.tfvars | cut -d '"' -f 2)

echo "=========================================="
echo "Validación de Deployment"
echo "=========================================="
echo "Proyecto: ${PROJECT_ID}"
echo "Región: ${REGION}"
echo ""

ERRORS=0

# ============================================================================
# 1. VALIDAR APIS HABILITADAS
# ============================================================================

log_info "Validando APIs habilitadas..."

REQUIRED_APIS=(
    "apikeys.googleapis.com"
    "pubsub.googleapis.com"
    "dataflow.googleapis.com"
    "bigquery.googleapis.com"
    "cloudfunctions.googleapis.com"
    "firestore.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    if gcloud services list --enabled --project=${PROJECT_ID} | grep -q ${api}; then
        log_success "${api}"
    else
        log_error "${api} no está habilitada"
        ((ERRORS++))
    fi
done

# ============================================================================
# 2. VALIDAR RECURSOS DE TERRAFORM
# ============================================================================

log_info "Validando recursos de Terraform..."

cd terraform

if [ -f "terraform.tfstate" ]; then
    RESOURCES=$(terraform show -json | jq -r '.values.root_module.resources | length')
    log_success "Terraform state existe (${RESOURCES} recursos)"
else
    log_error "Terraform state no encontrado"
    ((ERRORS++))
fi

cd ..

# ============================================================================
# 3. VALIDAR API KEYS
# ============================================================================

log_info "Validando API Keys..."

API_KEY_COUNT=$(gcloud services api-keys list --project=${PROJECT_ID} --filter="displayName:iot-devices" --format="value(name)" 2>/dev/null | wc -l)

if [ $API_KEY_COUNT -gt 0 ]; then
    log_success "API Key para dispositivos IoT encontrada"
    
    # Verificar restricciones
    API_KEY_NAME=$(gcloud services api-keys list --project=${PROJECT_ID} --filter="displayName:iot-devices" --format="value(name)" | head -n 1)
    log_info "API Key: ${API_KEY_NAME}"
else
    log_error "No se encontró API Key para dispositivos IoT"
    ((ERRORS++))
fi

# ============================================================================
# 4. VALIDAR PUB/SUB
# ============================================================================

log_info "Validando Pub/Sub..."

TOPICS=("sensor-telemetry" "sensor-alerts" "dead-letter-queue")

for topic in "${TOPICS[@]}"; do
    if gcloud pubsub topics describe ${topic} --project=${PROJECT_ID} &>/dev/null; then
        log_success "Topic: ${topic}"
    else
        log_error "Topic ${topic} no encontrado"
        ((ERRORS++))
    fi
done

# Verificar subscriptions
SUBS=$(gcloud pubsub subscriptions list --project=${PROJECT_ID} --format="value(name)" | wc -l)
log_info "Subscriptions encontradas: ${SUBS}"

# ============================================================================
# 5. VALIDAR BIGQUERY
# ============================================================================

log_info "Validando BigQuery..."

if bq ls --project_id=${PROJECT_ID} sensor_data &>/dev/null; then
    log_success "Dataset sensor_data existe"
    
    # Verificar tablas
    TABLES=("raw_readings" "aggregations_minute" "aggregations_hour")
    for table in "${TABLES[@]}"; do
        if bq show --project_id=${PROJECT_ID} sensor_data.${table} &>/dev/null; then
            ROW_COUNT=$(bq query --use_legacy_sql=false --project_id=${PROJECT_ID} --format=csv "SELECT COUNT(*) FROM \`sensor_data.${table}\`" | tail -n 1)
            log_success "Tabla ${table}: ${ROW_COUNT} filas"
        else
            log_error "Tabla ${table} no encontrada"
            ((ERRORS++))
        fi
    done
else
    log_error "Dataset sensor_data no encontrado"
    ((ERRORS++))
fi

# ============================================================================
# 6. VALIDAR CLOUD STORAGE
# ============================================================================

log_info "Validando Cloud Storage..."

BUCKETS=$(gsutil ls -p ${PROJECT_ID} | grep -E "(raw-data|dataflow-temp)" | wc -l)

if [ $BUCKETS -ge 2 ]; then
    log_success "Buckets encontrados: ${BUCKETS}"
else
    log_error "Faltan buckets de Cloud Storage"
    ((ERRORS++))
fi

# ============================================================================
# 7. VALIDAR FIRESTORE
# ============================================================================

log_info "Validando Firestore..."

if gcloud firestore databases describe --project=${PROJECT_ID} &>/dev/null; then
    log_success "Firestore database existe"
else
    log_error "Firestore database no encontrado"
    ((ERRORS++))
fi

# ============================================================================
# 8. VALIDAR CLOUD FUNCTIONS
# ============================================================================

log_info "Validando Cloud Functions..."

FUNCTIONS=("alert-processor" "realtime-updater")

for func in "${FUNCTIONS[@]}"; do
    if gcloud functions describe ${func} --region=${REGION} --project=${PROJECT_ID} &>/dev/null; then
        STATE=$(gcloud functions describe ${func} --region=${REGION} --project=${PROJECT_ID} --format="value(state)")
        log_success "Function ${func}: ${STATE}"
    else
        log_error "Function ${func} no encontrada"
        ((ERRORS++))
    fi
done

# ============================================================================
# 9. VALIDAR DATAFLOW
# ============================================================================

log_info "Validando Dataflow..."

JOBS=$(gcloud dataflow jobs list --region=${REGION} --project=${PROJECT_ID} --status=active --format="value(id)" | wc -l)

if [ $JOBS -gt 0 ]; then
    log_success "Jobs activos de Dataflow: ${JOBS}"
    
    # Detalles del primer job
    JOB_ID=$(gcloud dataflow jobs list --region=${REGION} --project=${PROJECT_ID} --status=active --format="value(id)" | head -n 1)
    JOB_STATE=$(gcloud dataflow jobs describe ${JOB_ID} --region=${REGION} --project=${PROJECT_ID} --format="value(state)")
    log_info "Estado del job: ${JOB_STATE}"
else
    log_warning "No hay jobs activos de Dataflow"
fi

# ============================================================================
# 10. PRUEBA DE CONECTIVIDAD
# ============================================================================

log_info "Probando conectividad end-to-end..."

# Verificar mensajes en Pub/Sub
log_info "Consultando mensajes en Pub/Sub..."
SUBSCRIPTION_ID=$(gcloud pubsub subscriptions list --project=${PROJECT_ID} --filter="name:telemetry" --format="value(name)" | head -n 1)

if [ -n "$SUBSCRIPTION_ID" ]; then
    MESSAGES=$(gcloud pubsub subscriptions pull ${SUBSCRIPTION_ID} --limit=1 --project=${PROJECT_ID} --format="value(message.data)" 2>/dev/null | wc -l)
    
    if [ $MESSAGES -gt 0 ]; then
        log_success "Mensajes fluyendo en Pub/Sub"
    else
        log_warning "No se detectaron mensajes (normal si no hay sensores activos)"
    fi
fi

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    log_success "VALIDACIÓN COMPLETADA SIN ERRORES"
else
    log_error "VALIDACIÓN COMPLETADA CON ${ERRORS} ERRORES"
fi
echo "=========================================="

exit $ERRORS
