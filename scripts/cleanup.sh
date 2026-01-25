#!/bin/bash

# ============================================================================
# Script de Limpieza de Recursos
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_warning() { echo -e "${YELLOW}[WARNING] ${1}${NC}"; }
log_success() { echo -e "${GREEN}[OK] ${1}${NC}"; }
log_error() { echo -e "${RED}[ERROR] ${1}${NC}"; }

echo "=========================================="
echo "LIMPIEZA DE RECURSOS - SISTEMA IOT"
echo "=========================================="
echo ""

log_warning "Este script eliminará TODOS los recursos del proyecto"
log_warning "Esta acción NO se puede deshacer"
echo ""

read -p "¿Estás seguro que deseas continuar? (escribir 'DELETE' para confirmar): " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Operación cancelada"
    exit 0
fi

# Leer configuración
PROJECT_ID=$(grep 'project_id' terraform/terraform.tfvars | cut -d '"' -f 2)
REGION=$(grep 'region' terraform/terraform.tfvars | cut -d '"' -f 2)

echo ""
echo "Proyecto: ${PROJECT_ID}"
echo "Región: ${REGION}"
echo ""

# 1. Detener Dataflow jobs
echo "Deteniendo jobs de Dataflow..."
gcloud dataflow jobs list --region=${REGION} --project=${PROJECT_ID} --status=active --format="value(id)" | while read job_id; do
    echo "  Cancelando job: ${job_id}"
    gcloud dataflow jobs cancel ${job_id} --region=${REGION} --project=${PROJECT_ID}
done
log_success "Dataflow jobs detenidos"

# 2. Destroy con Terraform
echo ""
echo "Ejecutando Terraform destroy..."
cd terraform
terraform destroy -auto-approve
cd ..
log_success "Recursos de Terraform eliminados"

# 3. Limpiar buckets (forzar eliminación)
echo ""
echo "Eliminando buckets de Cloud Storage..."
gsutil -m rm -r gs://*${PROJECT_ID}* 2>/dev/null || log_warning "Algunos buckets pueden no existir"
log_success "Buckets eliminados"

# 4. Eliminar claves locales
echo ""
echo "Eliminando claves locales..."
rm -rf .keys
log_success "Claves locales eliminadas"

# 5. Limpiar archivos temporales
echo ""
echo "Limpiando archivos temporales..."
rm -f deployment-info.txt
rm -f terraform/outputs.json
rm -f terraform/tfplan
log_success "Archivos temporales eliminados"

echo ""
echo "=========================================="
log_success "LIMPIEZA COMPLETADA"
echo "=========================================="
echo ""
echo "Recursos eliminados:"
echo "  - Dataflow jobs"
echo "  - Cloud Functions"
echo "  - Cloud IoT Core registry"
echo "  - Pub/Sub topics y subscriptions"
echo "  - BigQuery dataset"
echo "  - Cloud Storage buckets"
echo "  - Firestore collections"
echo ""
echo "NOTA: Las APIs de GCP permanecen habilitadas"
echo "Para deshabilitarlas manualmente:"
echo "  gcloud services disable NOMBRE_API --project=${PROJECT_ID}"
echo ""
