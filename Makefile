# =============================================================================
# Makefile - Sistema IoT de Monitoreo de Calidad de Aguas
# =============================================================================

PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)
REGION ?= us-central1
ENVIRONMENT ?= prod

# Colores
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
NC := \033[0m

# Nombres de recursos
TOPIC_NAME := sensor-telemetry
ALERT_TOPIC := sensor-alerts
DLQ_TOPIC := dead-letter-queue
DATASET_NAME := sensor_data
RECEIVER_FUNCTION := alert-processor
UPDATER_FUNCTION := realtime-updater

.PHONY: help
help:
	@echo ""
	@echo "$(CYAN)============================================================$(NC)"
	@echo "$(CYAN) Sistema IoT de Monitoreo de Calidad de Aguas              $(NC)"
	@echo "$(CYAN)============================================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Configuración Actual:$(NC)"
	@echo "  PROJECT_ID:  $(PROJECT_ID)"
	@echo "  REGION:      $(REGION)"
	@echo "  ENVIRONMENT: $(ENVIRONMENT)"
	@echo ""
	@echo "$(YELLOW)Setup Inicial:$(NC)"
	@echo "  $(GREEN)make setup$(NC)          - Setup completo (APIs + Terraform + Dataflow)"
	@echo "  $(GREEN)make setup-apis$(NC)     - Habilitar APIs de GCP"
	@echo "  $(GREEN)make setup-tfvars$(NC)   - Crear terraform.tfvars"
	@echo ""
	@echo "$(YELLOW)Infraestructura (Terraform):$(NC)"
	@echo "  $(GREEN)make init$(NC)           - Inicializar Terraform"
	@echo "  $(GREEN)make plan$(NC)           - Ver plan de cambios"
	@echo "  $(GREEN)make apply$(NC)          - Aplicar infraestructura"
	@echo "  $(GREEN)make destroy$(NC)        - Destruir infraestructura"
	@echo "  $(GREEN)make output$(NC)         - Ver outputs de Terraform"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@echo "  $(GREEN)make deploy-dataflow$(NC) - Desplegar pipeline de Dataflow"
	@echo "  $(GREEN)make deploy-all$(NC)     - Deploy completo (Terraform + Dataflow)"
	@echo ""
	@echo "$(YELLOW)Testing:$(NC)"
	@echo "  $(GREEN)make test$(NC)           - Test completo (upload + verify)"
	@echo "  $(GREEN)make test-device$(NC)    - Simular dispositivo IoT"
	@echo "  $(GREEN)make test-curl$(NC)      - Test con curl directo"
	@echo "  $(GREEN)make test-verify$(NC)    - Verificar datos en BigQuery"
	@echo ""
	@echo "$(YELLOW)Monitoreo:$(NC)"
	@echo "  $(GREEN)make logs-functions$(NC) - Logs de Cloud Functions"
	@echo "  $(GREEN)make logs-dataflow$(NC)  - Logs de Dataflow"
	@echo "  $(GREEN)make status$(NC)         - Estado de recursos"
	@echo "  $(GREEN)make query-bq$(NC)       - Query datos en BigQuery"
	@echo ""
	@echo "$(YELLOW)Configuración Dispositivos:$(NC)"
	@echo "  $(GREEN)make show-config$(NC)    - Mostrar config para Arduino"
	@echo "  $(GREEN)make get-sa-key$(NC)     - Obtener Service Account Key"
	@echo "  $(GREEN)make api-key$(NC)        - Mostrar API Key (DEPRECADO)"
	@echo "  $(GREEN)make pubsub-url$(NC)     - Mostrar URL de Pub/Sub"
	@echo ""
	@echo "$(YELLOW)Utilidades:$(NC)"
	@echo "  $(GREEN)make validate$(NC)       - Validar deployment"
	@echo "  $(GREEN)make clean$(NC)          - Limpiar archivos temporales"
	@echo ""

# =============================================================================
# PREREQUISITOS
# =============================================================================

.PHONY: check-prereqs
check-prereqs:
	@echo "$(BLUE)[INFO]$(NC) Validando prerequisitos..."
	@command -v gcloud >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) gcloud CLI no instalado"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) Terraform no instalado"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) Python 3 no instalado"; exit 1; }
	@echo "$(GREEN)[✓]$(NC) gcloud CLI instalado"
	@echo "$(GREEN)[✓]$(NC) Terraform instalado ($$(terraform version | head -n 1))"
	@echo "$(GREEN)[✓]$(NC) Python 3 instalado ($$(python3 --version))"

.PHONY: check-project
check-project:
	@if [ -z "$(PROJECT_ID)" ]; then \
		echo "$(RED)[ERROR]$(NC) PROJECT_ID no configurado"; \
		echo "Usar: make <target> PROJECT_ID=tu-proyecto-id"; \
		exit 1; \
	fi

# =============================================================================
# SETUP INICIAL
# =============================================================================

.PHONY: setup-tfvars
setup-tfvars:
	@if [ ! -f terraform/terraform.tfvars ]; then \
		echo "$(BLUE)[INFO]$(NC) Creando terraform.tfvars..."; \
		cp terraform/terraform.tfvars.example terraform/terraform.tfvars 2>/dev/null || { \
			echo "project_id = \"$(PROJECT_ID)\"" > terraform/terraform.tfvars; \
			echo "region = \"$(REGION)\"" >> terraform/terraform.tfvars; \
			echo "environment = \"$(ENVIRONMENT)\"" >> terraform/terraform.tfvars; \
		}; \
		echo "$(GREEN)[✓]$(NC) terraform.tfvars creado"; \
	else \
		echo "$(YELLOW)[!]$(NC) terraform.tfvars ya existe"; \
	fi

.PHONY: setup-apis
setup-apis: check-project
	@echo "$(BLUE)[INFO]$(NC) Habilitando APIs de GCP..."
	@gcloud services enable apikeys.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable pubsub.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable dataflow.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable bigquery.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable cloudfunctions.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable cloudbuild.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable firestore.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable storage-api.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable logging.googleapis.com --project=$(PROJECT_ID)
	@gcloud services enable monitoring.googleapis.com --project=$(PROJECT_ID)
	@echo "$(GREEN)[✓]$(NC) APIs habilitadas"

.PHONY: setup
setup: check-prereqs check-project setup-apis setup-tfvars init apply deploy-dataflow
	@echo ""
	@echo "$(GREEN)============================================================$(NC)"
	@echo "$(GREEN) ✓ SETUP COMPLETADO                                         $(NC)"
	@echo "$(GREEN)============================================================$(NC)"
	@echo ""
	@$(MAKE) show-config

# =============================================================================
# TERRAFORM
# =============================================================================

.PHONY: init
init: setup-tfvars
	@echo "$(BLUE)[INFO]$(NC) Inicializando Terraform..."
	@cd terraform && terraform init
	@echo "$(GREEN)[✓]$(NC) Terraform inicializado"

.PHONY: plan
plan: init
	@echo "$(BLUE)[INFO]$(NC) Generando plan..."
	@cd terraform && terraform plan

.PHONY: apply
apply: init
	@echo "$(BLUE)[INFO]$(NC) Aplicando infraestructura..."
	@cd terraform && terraform apply
	@cd terraform && terraform output -json > outputs.json
	@echo "$(GREEN)[✓]$(NC) Infraestructura desplegada"

.PHONY: apply-auto
apply-auto: init
	@cd terraform && terraform apply -auto-approve
	@cd terraform && terraform output -json > outputs.json

.PHONY: destroy
destroy:
	@echo "$(YELLOW)[!]$(NC) Destruyendo infraestructura..."
	@cd terraform && terraform destroy

.PHONY: output
output:
	@cd terraform && terraform output

# =============================================================================
# DEPLOYMENT
# =============================================================================

.PHONY: deploy-dataflow
deploy-dataflow:
	@echo "$(BLUE)[INFO]$(NC) Desplegando pipeline de Dataflow..."
	@echo "$(BLUE)[INFO]$(NC) Configurando entorno virtual Python..."
	@if [ ! -d "dataflow-pipeline/venv" ]; then \
		echo "$(YELLOW)[!]$(NC) Creando entorno virtual..."; \
		cd dataflow-pipeline && python3.11 -m venv venv; \
	fi
	@echo "$(BLUE)[INFO]$(NC) Instalando dependencias..."
	@cd dataflow-pipeline && . venv/bin/activate && pip install --upgrade pip setuptools wheel -q && pip install -r requirements.txt -q
	@echo "$(BLUE)[INFO]$(NC) Iniciando deployment del pipeline..."
	@SUBSCRIPTION_ID=$$(cd terraform && terraform output -json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['telemetry_subscription_id']['value'])" 2>/dev/null || echo "projects/$(PROJECT_ID)/subscriptions/sensor-telemetry-dataflow-sub"); \
	TEMP_BUCKET=$$(cd terraform && terraform output -json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['temp_bucket_name']['value'])" 2>/dev/null || echo "$(PROJECT_ID)-dataflow-temp"); \
	cd dataflow-pipeline && . venv/bin/activate && python3.11 pipeline.py \
		--project=$(PROJECT_ID) \
		--region=$(REGION) \
		--zone=$(REGION)-f \
		--runner=DataflowRunner \
		--subscription=$$SUBSCRIPTION_ID \
		--dataset=$(DATASET_NAME) \
		--raw_table=raw_readings \
		--agg_table=aggregations_minute \
		--output_bucket=gs://$$TEMP_BUCKET/raw-data \
		--temp_location=gs://$$TEMP_BUCKET/dataflow/temp \
		--staging_location=gs://$$TEMP_BUCKET/dataflow/staging \
		--job_name=water-quality-telemetry-$$(date +%Y%m%d-%H%M%S) \
		--streaming \
		--max_num_workers=5 \
		--num_workers=1 \
		--autoscaling_algorithm=THROUGHPUT_BASED \
		--machine_type=n1-standard-2 \
		--experiments=use_runner_v2
	@echo "$(GREEN)[✓]$(NC) Pipeline de Dataflow desplegado"

.PHONY: deploy-all
deploy-all: apply deploy-dataflow
	@echo "$(GREEN)[✓]$(NC) Deployment completo"

# =============================================================================
# TESTING
# =============================================================================

.PHONY: test-device
test-device:
	@echo "$(BLUE)[TEST]$(NC) Simulando dispositivo IoT..."
	@python3 scripts/test-device.py --device-id test-001 --interval 5 --count 5

.PHONY: test-curl
test-curl:
	@echo "$(BLUE)[TEST]$(NC) Test con curl usando Service Account..."
	@SA_KEY=$$(cd terraform && terraform output -raw service_account_key 2>/dev/null); \
	PUBSUB_URL=$$(cd terraform && terraform output -raw pubsub_publish_url 2>/dev/null); \
	DATA=$$(echo '{"device_id":"test-curl","temperature":25.5,"humidity":65.0,"timestamp":"'$$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' | base64); \
	echo "$$SA_KEY" > /tmp/sa-key.json; \
	ACCESS_TOKEN=$$(gcloud auth application-default print-access-token --credential-file-override=/tmp/sa-key.json 2>/dev/null || gcloud auth print-access-token 2>/dev/null); \
	rm -f /tmp/sa-key.json; \
	curl -X POST "$$PUBSUB_URL" \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $$ACCESS_TOKEN" \
		-d "{\"messages\":[{\"data\":\"$$DATA\"}]}" | jq .

.PHONY: test-verify
test-verify:
	@echo "$(BLUE)[TEST]$(NC) Verificando datos en BigQuery..."
	@bq query --use_legacy_sql=false \
		"SELECT device_id, temperature, humidity, timestamp FROM \`$(PROJECT_ID).$(DATASET_NAME).raw_readings\` ORDER BY timestamp DESC LIMIT 100"

.PHONY: test-wait
test-wait:
	@echo "$(BLUE)[INFO]$(NC) Esperando procesamiento (30s)..."
	@sleep 30
	@echo "$(GREEN)[✓]$(NC) Completado"

.PHONY: test
test: test-curl test-wait test-verify
	@echo ""
	@echo "$(GREEN)============================================================$(NC)"
	@echo "$(GREEN) ✓ PRUEBAS COMPLETADAS                                      $(NC)"
	@echo "$(GREEN)============================================================$(NC)"

# =============================================================================
# MONITOREO
# =============================================================================

.PHONY: logs-functions
logs-functions:
	@echo "$(BLUE)[INFO]$(NC) Logs de Cloud Functions..."
	@echo ""
	@echo "$(CYAN)Alert Processor:$(NC)"
	@gcloud functions logs read $(RECEIVER_FUNCTION) --gen2 --region=$(REGION) --limit=10 2>/dev/null || echo "No hay logs"
	@echo ""
	@echo "$(CYAN)Realtime Updater:$(NC)"
	@gcloud functions logs read $(UPDATER_FUNCTION) --gen2 --region=$(REGION) --limit=10 2>/dev/null || echo "No hay logs"

.PHONY: logs-dataflow
logs-dataflow:
	@echo "$(BLUE)[INFO]$(NC) Jobs de Dataflow..."
	@gcloud dataflow jobs list --region=$(REGION) --project=$(PROJECT_ID) --status=active

.PHONY: query-bq
query-bq:
	@echo "$(BLUE)[INFO]$(NC) Consultando BigQuery..."
	@bq query --use_legacy_sql=false \
		"SELECT device_id, COUNT(*) as total, AVG(temperature) as avg_temp, AVG(humidity) as avg_hum FROM \`$(PROJECT_ID).$(DATASET_NAME).raw_readings\` WHERE DATE(timestamp) = CURRENT_DATE() GROUP BY device_id"

.PHONY: status
status:
	@echo ""
	@echo "$(CYAN)============================================================$(NC)"
	@echo "$(CYAN) ESTADO DE RECURSOS                                         $(NC)"
	@echo "$(CYAN)============================================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Pub/Sub Topics:$(NC)"
	@gcloud pubsub topics list --project=$(PROJECT_ID) --filter="name:sensor" --format="table(name)" 2>/dev/null || echo "  $(RED)[✗]$(NC) No encontrado"
	@echo ""
	@echo "$(YELLOW)BigQuery Dataset:$(NC)"
	@bq ls --project_id=$(PROJECT_ID) $(DATASET_NAME) 2>/dev/null | head -3 || echo "  $(RED)[✗]$(NC) No encontrado"
	@echo ""
	@echo "$(YELLOW)Cloud Functions:$(NC)"
	@gcloud functions list --gen2 --region=$(REGION) --project=$(PROJECT_ID) --format="table(name,state)" 2>/dev/null || echo "  $(RED)[✗]$(NC) No encontrado"
	@echo ""
	@echo "$(YELLOW)Dataflow Jobs:$(NC)"
	@gcloud dataflow jobs list --region=$(REGION) --project=$(PROJECT_ID) --status=active --format="table(id,name,state)" 2>/dev/null || echo "  $(BLUE)[INFO]$(NC) No hay jobs activos"

# =============================================================================
# CONFIGURACIÓN DISPOSITIVOS
# =============================================================================

.PHONY: api-key
api-key:
	@cd terraform && terraform output -raw api_key_iot_devices 2>/dev/null || echo "$(RED)[ERROR]$(NC) API Key no disponible"

.PHONY: pubsub-url
pubsub-url:
	@cd terraform && terraform output -raw pubsub_publish_url 2>/dev/null || echo "$(RED)[ERROR]$(NC) URL no disponible"

.PHONY: show-config
show-config:
	@echo ""
	@echo "$(CYAN)============================================================$(NC)"
	@echo "$(CYAN) CONFIGURACIÓN PARA DISPOSITIVOS ARDUINO                    $(NC)"
	@echo "$(CYAN)============================================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Archivo:$(NC) arduino-code/sensor_http/sensor_http.ino"
	@echo ""
	@echo "$(YELLOW)PROJECT_ID:$(NC)"
	@echo "  $(PROJECT_ID)"
	@echo ""
	@echo "$(YELLOW)TOPIC_NAME:$(NC)"
	@echo "  $(TOPIC_NAME)"
	@echo ""
	@echo "$(YELLOW)AUTENTICACIÓN (NUEVA):$(NC)"
	@echo "  Usar Service Account Key (más seguro que API Key)"
	@echo "  Para obtener la key: make get-sa-key"
	@echo ""
	@echo "$(YELLOW)Pub/Sub URL completa:$(NC)"
	@cd terraform && terraform output -raw pubsub_publish_url 2>/dev/null || echo "  $(RED)[ERROR]$(NC) No disponible"
	@echo ""
	@echo ""
	@echo "$(YELLOW)WiFi:$(NC) Configurar SSID y password en sensor_http.ino"
	@echo ""

.PHONY: get-sa-key
get-sa-key:
	@echo "$(BLUE)[INFO]$(NC) Service Account Key (guardar en archivo seguro):"
	@cd terraform && terraform output -raw service_account_key 2>/dev/null || echo "$(RED)[ERROR]$(NC) No disponible"

.PHONY: create-env
create-env:
	@echo "$(BLUE)[INFO]$(NC) Creando archivo .env..."
	@API_KEY=$$(cd terraform && terraform output -raw api_key_iot_devices 2>/dev/null); \
	PUBSUB_URL=$$(cd terraform && terraform output -raw pubsub_publish_url 2>/dev/null); \
	echo "# Configuración para dispositivos IoT (HTTP/Pub/Sub)" > .env; \
	echo "API_KEY=$$API_KEY" >> .env; \
	echo "PUBSUB_PUBLISH_URL=$$PUBSUB_URL" >> .env; \
	echo "PROJECT_ID=$(PROJECT_ID)" >> .env; \
	echo "TOPIC_NAME=$(TOPIC_NAME)" >> .env
	@echo "$(GREEN)[✓]$(NC) Archivo .env creado"
	@echo "$(YELLOW)[!]$(NC) IMPORTANTE: No subir .env a git"

# =============================================================================
# VALIDACIÓN
# =============================================================================

.PHONY: validate
validate:
	@echo "$(BLUE)[INFO]$(NC) Ejecutando validación..."
	@./scripts/validate-deployment.sh

# =============================================================================
# LIMPIEZA
# =============================================================================

.PHONY: clean
clean:
	@echo "$(BLUE)[INFO]$(NC) Limpiando archivos temporales..."
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl
	@rm -f terraform/terraform.tfstate.backup
	@rm -f terraform/outputs.json
	@rm -f .env
	@rm -f dataflow-pipeline/*.pyc
	@rm -rf dataflow-pipeline/__pycache__
	@echo "$(GREEN)[✓]$(NC) Archivos limpiados"

.DEFAULT_GOAL := help
