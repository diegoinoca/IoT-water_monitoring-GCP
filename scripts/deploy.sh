#!/bin/bash

# ============================================================================
# Script de Despliegue - Sistema IoT de Monitoreo de Calidad de Aguas
# ============================================================================

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
log_info() {
    echo -e "${BLUE}[INFO] ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}[OK] ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] ${1}${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] ${1}${NC}"
}

# ============================================================================
# 1. VALIDACIÓN DE PREREQUISITOS
# ============================================================================

log_info "Validando prerequisitos..."

# Verificar gcloud CLI
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI no está instalado"
    echo "Instalar desde: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
log_success "gcloud CLI instalado"

# Verificar Terraform
if ! command -v terraform &> /dev/null; then
    log_error "Terraform no está instalado"
    echo "Instalar desde: https://www.terraform.io/downloads"
    exit 1
fi
log_success "Terraform instalado ($(terraform version | head -n 1))"

# Verificar Python
if ! command -v python3 &> /dev/null; then
    log_error "Python 3 no está instalado"
    exit 1
fi
log_success "Python 3 instalado ($(python3 --version))"

# ============================================================================
# 2. CONFIGURACIÓN DE VARIABLES
# ============================================================================

log_info "Configurando variables de entorno..."

# Leer configuración o solicitar al usuario
if [ -f "terraform/terraform.tfvars" ]; then
    log_success "Usando terraform.tfvars existente"
    PROJECT_ID=$(grep 'project_id' terraform/terraform.tfvars | cut -d '"' -f 2)
    REGION=$(grep 'region' terraform/terraform.tfvars | cut -d '"' -f 2)
else
    read -p "Ingrese el ID del proyecto GCP: " PROJECT_ID
    read -p "Ingrese la región GCP (default: us-central1): " REGION
    REGION=${REGION:-us-central1}
    
    # Crear terraform.tfvars desde ejemplo
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    
    # Actualizar valores
    sed -i.bak "s/tu-proyecto-gcp-id/${PROJECT_ID}/" terraform/terraform.tfvars
    sed -i.bak "s/us-central1/${REGION}/" terraform/terraform.tfvars
    
    log_warning "Por favor edita terraform/terraform.tfvars con tus valores específicos"
    read -p "Presiona Enter cuando hayas terminado..."
fi

log_info "Proyecto: ${PROJECT_ID}"
log_info "Región: ${REGION}"

# ============================================================================
# 3. AUTENTICACIÓN Y CONFIGURACIÓN DE GCP
# ============================================================================

log_info "Configurando autenticación de GCP..."

# Verificar autenticación
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    log_warning "No hay autenticación activa"
    gcloud auth login
fi
log_success "Autenticación configurada"

# Configurar proyecto
gcloud config set project ${PROJECT_ID}
log_success "Proyecto configurado: ${PROJECT_ID}"

# ============================================================================
# 4. HABILITAR APIs DE GCP
# ============================================================================

log_info "Habilitando APIs necesarias de GCP..."

APIS=(
    "apikeys.googleapis.com"
    "pubsub.googleapis.com"
    "dataflow.googleapis.com"
    "bigquery.googleapis.com"
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "firestore.googleapis.com"
    "storage-api.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "secretmanager.googleapis.com"
)

for api in "${APIS[@]}"; do
    log_info "Habilitando ${api}..."
    gcloud services enable ${api} --project=${PROJECT_ID}
done
log_success "APIs habilitadas"

# ============================================================================
# 5. DESPLIEGUE DE INFRAESTRUCTURA CON TERRAFORM
# ============================================================================

log_info "Desplegando infraestructura con Terraform..."

cd terraform

# Inicializar Terraform
log_info "Inicializando Terraform..."
terraform init
log_success "Terraform inicializado"

# Validar configuración
log_info "Validando configuración..."
terraform validate
log_success "Configuración válida"

# Planear despliegue
log_info "Planeando despliegue..."
terraform plan -out=tfplan
log_success "Plan generado"

# Confirmar despliegue
read -p "¿Deseas continuar con el despliegue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log_warning "Despliegue cancelado"
    exit 0
fi

# Aplicar configuración
log_info "Aplicando configuración de Terraform..."
terraform apply tfplan
log_success "Infraestructura desplegada"

# Guardar outputs
terraform output -json > outputs.json
log_success "Outputs guardados en terraform/outputs.json"

cd ..

# ============================================================================
# 6. DESPLEGAR CLOUD FUNCTIONS
# ============================================================================

log_info "Desplegando Cloud Functions..."

# Las funciones se despliegan automáticamente con Terraform
# Verificar que estén activas
log_info "Verificando Cloud Functions..."
gcloud functions list --project=${PROJECT_ID} --region=${REGION}
log_success "Cloud Functions verificadas"

# ============================================================================
# 7. DESPLEGAR PIPELINE DE DATAFLOW
# ============================================================================

log_info "Preparando pipeline de Dataflow..."

cd dataflow-pipeline

# Instalar dependencias
log_info "Instalando dependencias de Python..."
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt
log_success "Dependencias instaladas"

# Obtener variables de Terraform outputs
SUBSCRIPTION_ID=$(cat ../terraform/outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['telemetry_subscription_id']['value'])")
TEMP_BUCKET=$(cat ../terraform/outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['temp_bucket_name']['value'])")

log_info "Subscription ID: ${SUBSCRIPTION_ID}"
log_info "Temp Bucket: ${TEMP_BUCKET}"

# Desplegar pipeline
log_info "Desplegando pipeline de Dataflow..."

python3 pipeline.py \
    --project=${PROJECT_ID} \
    --region=${REGION} \
    --runner=DataflowRunner \
    --subscription=projects/${PROJECT_ID}/subscriptions/${SUBSCRIPTION_ID} \
    --dataset=sensor_data \
    --raw_table=raw_readings \
    --agg_table=aggregations_minute \
    --output_bucket=gs://${TEMP_BUCKET}/raw-data \
    --temp_location=gs://${TEMP_BUCKET}/dataflow/temp \
    --staging_location=gs://${TEMP_BUCKET}/dataflow/staging \
    --job_name=water-quality-telemetry-$(date +%Y%m%d-%H%M%S) \
    --streaming \
    --max_num_workers=10 \
    --autoscaling_algorithm=THROUGHPUT_BASED

log_success "Pipeline de Dataflow desplegado"

cd ..

# ============================================================================
# 8. CONFIGURAR API KEY PARA DISPOSITIVOS
# ============================================================================

log_info "Obteniendo API Key para dispositivos IoT..."

# Obtener API Key de Terraform outputs
API_KEY=$(cat terraform/outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['api_key_iot_devices']['value'])")
PUBSUB_URL=$(cat terraform/outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['pubsub_publish_url']['value'])")

# Guardar en archivo .env para usar en dispositivos
cat > .env << EOF
# Configuración para dispositivos IoT (HTTP/Pub/Sub)
API_KEY=${API_KEY}
PUBSUB_PUBLISH_URL=${PUBSUB_URL}
PROJECT_ID=${PROJECT_ID}
TOPIC_NAME=sensor-telemetry
EOF

log_success "API Key configurada y guardada en .env"
log_warning "IMPORTANTE: No subir .env a git. El archivo contiene credenciales sensibles."

# Agregar .env a .gitignore si no existe
if ! grep -q "^\.env$" .gitignore 2>/dev/null; then
    echo ".env" >> .gitignore
    log_info "Agregado .env a .gitignore"
fi

# ============================================================================
# 9. VALIDACIÓN POST-DESPLIEGUE
# ============================================================================

log_info "Ejecutando validaciones post-despliegue..."

# Verificar que Pub/Sub tiene mensajes (esperar 30 segundos)
log_info "Esperando mensajes en Pub/Sub (30 segundos)..."
sleep 30

MESSAGE_COUNT=$(gcloud pubsub subscriptions pull ${SUBSCRIPTION_ID} --limit=1 --auto-ack --project=${PROJECT_ID} | wc -l)
if [ $MESSAGE_COUNT -gt 0 ]; then
    log_success "Pub/Sub recibiendo mensajes"
else
    log_warning "No se detectaron mensajes en Pub/Sub (esto es normal si no hay sensores activos)"
fi

# Verificar BigQuery
log_info "Verificando dataset de BigQuery..."
bq ls --project_id=${PROJECT_ID} sensor_data && log_success "Dataset de BigQuery existe"

# Verificar Firestore
log_info "Verificando Firestore..."
gcloud firestore databases describe --project=${PROJECT_ID} && log_success "Firestore configurado"

# ============================================================================
# 10. RESUMEN Y SIGUIENTES PASOS
# ============================================================================

echo ""
echo "=========================================="
echo -e "${GREEN}[OK] DESPLIEGUE COMPLETADO EXITOSAMENTE${NC}"
echo "=========================================="
echo ""
echo "Recursos Desplegados:"
echo "  - API Keys (para autenticación de dispositivos)"
echo "  - Cloud Pub/Sub Topics & Subscriptions"
echo "  - Cloud Dataflow Pipeline (streaming)"
echo "  - BigQuery Dataset & Tables"
echo "  - Cloud Storage Buckets"
echo "  - Firestore Database"
echo "  - Cloud Functions (Alert Processor, Realtime Updater)"
echo ""
echo "Enlaces Útiles:"
echo "  - Cloud Console: https://console.cloud.google.com/?project=${PROJECT_ID}"
echo "  - API Keys: https://console.cloud.google.com/apis/credentials?project=${PROJECT_ID}"
echo "  - Pub/Sub Topics: https://console.cloud.google.com/cloudpubsub/topic/list?project=${PROJECT_ID}"
echo "  - Dataflow Jobs: https://console.cloud.google.com/dataflow/jobs?project=${PROJECT_ID}"
echo "  - BigQuery: https://console.cloud.google.com/bigquery?project=${PROJECT_ID}"
echo ""
echo "Siguientes Pasos:"
echo "  1. Copiar API Key de .env a dispositivos Arduino (sensor_http.ino)"
echo "  2. Ejecutar script de prueba: python3 scripts/test-http-device.py"
echo "  3. Verificar datos en BigQuery"
echo "  4. Configurar dashboards en Looker Studio"
echo "  5. Personalizar umbrales de alertas en variables de Terraform"
echo ""
echo "Configuración de Dispositivos:"
echo "  - API Key: Ver archivo .env (NO COMPARTIR)"
echo "  - Pub/Sub URL: ${PUBSUB_URL}"
echo "  - Código Arduino: arduino-code/sensor_http/sensor_http.ino"
echo ""
echo "IMPORTANTE: Mantener API Key segura. Rotar cada 90 días."
echo ""

# Guardar información de despliegue
cat > deployment-info.txt << EOF
Despliegue completado: $(date)
Proyecto: ${PROJECT_ID}
Región: ${REGION}
Pub/Sub URL: ${PUBSUB_URL}
Subscription: ${SUBSCRIPTION_ID}

Arquitectura: HTTP/Pub/Sub directo (migrado de IoT Core deprecado)

Comandos útiles:
- Ver logs de Dataflow: gcloud dataflow jobs list --project=${PROJECT_ID}
- Test de publicación: curl -X POST "${PUBSUB_URL}" -H "X-Goog-Api-Key: API_KEY" -d '{"messages":[{"data":"base64_encoded_json"}]}'
- Query BigQuery: bq query --use_legacy_sql=false 'SELECT * FROM \`${PROJECT_ID}.sensor_data.raw_readings\` LIMIT 10'
- Ver API Keys: gcloud services api-keys list --project=${PROJECT_ID}
EOF

log_success "Información de despliegue guardada en deployment-info.txt"

exit 0
