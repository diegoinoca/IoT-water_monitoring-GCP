# Sistema IoT de Monitoreo de Calidad de Aguas en Tiempo Real

## Descripción General

Sistema distribuido de telemetría IoT para monitoreo ambiental en tiempo real, enfocado en la calidad del agua utilizando sensores DHT11 (temperatura y humedad) conectados a Arduino+ESP32. El sistema procesa datos en streaming, genera alertas automáticas y proporciona visualizaciones en tiempo real.

## Arquitectura

El sistema está construido sobre Google Cloud Platform (GCP) e implementa los siguientes componentes:

- **Capa de Dispositivos**: Arduino + DHT11 + ESP32 WiFi (HTTP Client)
- **Autenticación**: Google Cloud API Keys con restricciones
- **Ingesta**: Cloud Pub/Sub (HTTP REST API directo)
- **Procesamiento**: Cloud Dataflow (Apache Beam) + Cloud Functions
- **Almacenamiento**: BigQuery + Cloud Storage + Firestore
- **Visualización**: Looker Studio + Web Dashboard

## Estructura del Proyecto

```
trabajofinalv2/
├── README.md                          # Este archivo
├── spec.md                            # Especificaciones detalladas
├── terraform/                         # Infraestructura como código
│   ├── main.tf                       # Configuración principal
│   ├── variables.tf                  # Variables de entrada
│   ├── outputs.tf                    # Outputs del deployment
│   ├── terraform.tfvars.example      # Ejemplo de variables
│   ├── versions.tf                   # Versiones de providers
│   ├── modules/                      # Módulos reutilizables
│   │   ├── pubsub/                   # Topics y subscriptions
│   │   ├── dataflow/                 # Jobs de Dataflow
│   │   ├── bigquery/                 # Datasets y tablas
│   │   ├── firestore/                # Base de datos NoSQL
│   │   ├── cloud-functions/          # Funciones serverless
│   │   └── storage/                  # Cloud Storage buckets
├── dataflow-pipeline/                # Pipeline de procesamiento streaming
│   ├── pipeline.py                   # Código Apache Beam
│   ├── requirements.txt              # Dependencias Python
│   └── setup.py                      # Setup del pipeline
├── cloud-functions/                  # Cloud Functions
│   ├── alert-processor/              # Procesador de alertas
│   │   ├── main.py
│   │   └── requirements.txt
│   └── realtime-updater/             # Actualizador tiempo real
│       ├── main.py
│       └── requirements.txt
├── arduino-code/                     # Código para dispositivos IoT
│   ├── sensor_http/                  # Código principal
│   │   └── sensor_http.ino          # Sketch Arduino con HTTP Client
│   └── README.md                     # Instrucciones de configuración
├── docs/                             # Documentación técnica
│   ├── documento-tecnico.md          # Documento principal
│   ├── analisis-alternativas.md      # Comparación de tecnologías
│   ├── estimacion-costos.md          # Análisis de costos GCP
│   ├── diagramas/                    # Diagramas de arquitectura
│   └── screenshots/                  # Capturas de pantalla
├── scripts/                          # Scripts de utilidad
│   ├── deploy.sh                     # Script de despliegue
│   ├── test-device.py                # Simulador de dispositivo
│   ├── validate-deployment.sh        # Validación de recursos
│   └── cleanup.sh                    # Limpieza de recursos
```

### Prerrequisitos

- Cuenta de Google Cloud Platform
- Terraform >= 1.5.0
- Python 3.11 (Apache Beam no soporta Python 3.13)
- gcloud CLI instalado y configurado
- Arduino IDE (para programar dispositivos)

### Deployment Completo

```bash
# Setup completo (APIs + Terraform + Dataflow)
make setup

# O paso por paso:
make setup-apis      # Habilitar APIs de GCP
make init            # Inicializar Terraform
make apply           # Desplegar infraestructura
make deploy-dataflow # Desplegar pipeline
```

### Configurar Dispositivos IoT

```bash
# Ver configuración para Arduino
make show-config

# Crear archivo .env con credenciales
make create-env
```

Ver instrucciones detalladas en [arduino-code/README.md](arduino-code/README.md)

## Características Principales

### Funcionales
- ✅ Captura de datos cada 30 segundos
- ✅ Procesamiento en tiempo real con Apache Beam
- ✅ Alertas automáticas por umbrales
- ✅ Almacenamiento raw y agregado
- ✅ Dashboard en tiempo real
- ✅ Analytics histórico

### No Funcionales
- Latencia de ingesta < 500ms
- Procesamiento < 5 segundos
- Alertas < 10 segundos
- Soporta 10-1000 dispositivos
- Autenticación con API Keys gestionadas por GCP
- Protocolo: HTTPS/TLS 1.3
- Costo estimado: $115-200/mes (100 sensores)

## Configuración de Alertas

Umbrales predeterminados:
- Temperatura > 30°C → Alerta por correo
- Humedad < 20% o > 80% → Alerta crítica
- Dispositivo sin datos > 5 min → Alerta de conectividad
- Error HTTP 401/403 → Revisar API Key

## Estimación de Costos

Para 100 sensores activos:
- Pub/Sub Ingesta: ~$0.35/mes
- Pub/Sub Subscriptions: ~$0/mes (tier gratuito)
- Dataflow: ~$100/mes
- BigQuery: ~$8/mes
- Cloud Functions: ~$0/mes (tier gratuito)
- Firestore: ~$5/mes
- Storage: ~$2/mes
- API Keys: $0 (servicio gratuito)
- **Total: ~$115.35/mes**

**Costo por sensor:** $1.15/mes

Ver análisis detallado en [docs/estimacion-costos.md](docs/estimacion-costos.md)

## Testing

```bash
# Validar deployment de Terraform
./scripts/validate-deployment.sh

# Simular dispositivo IoT
python scripts/test-device.py --device-id test-001

# Test manual con curl
curl -X POST "https://pubsub.googleapis.com/v1/projects/PROJECT/topics/TOPIC:publish" \
  -H "X-Goog-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"data":"BASE64_ENCODED_JSON"}]}'

# Ejecutar pruebas del pipeline
cd dataflow-pipeline
pytest tests/
```

## Documentación

- [Documento Técnico Completo](docs/documento-tecnico.md)
- [Análisis de Alternativas](docs/analisis-alternativas.md)
- [Estimación de Costos](docs/estimacion-costos.md)
- [Configuración Arduino](arduino-code/README.md)

## Troubleshooting

### Error: API Keys requiere quota project

**Síntoma:**
```
Error 403: Your application is authenticating by using local Application Default Credentials.
The apikeys.googleapis.com API requires a quota project, which is not set by default.
```

**Solución:**

1. **Configurar quota project en ADC:**
```bash
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

2. **Configurar Terraform provider (ya incluido en `terraform/versions.tf`):**
```hcl
provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}
```

3. **Habilitar la API:**
```bash
gcloud services enable apikeys.googleapis.com --project=YOUR_PROJECT_ID
```

### Error: Python externally-managed-environment (macOS)

**Síntoma:**
```
error: externally-managed-environment
This environment is externally managed
```

**Solución:**

Usar Python 3.11 (Apache Beam no soporta Python 3.13 aún) con entorno virtual:

```bash
cd dataflow-pipeline
rm -rf venv
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

**Verificar versión compatible:**
```bash
python3.11 --version  # Debe ser Python 3.11.x
```

### Error: GroupByKey en pipeline streaming

**Síntoma:**
```
ValueError: GroupByKey cannot be applied to an unbounded PCollection
with global windowing and a default trigger
```

**Causa:**
`WriteToText` no funciona correctamente con pipelines streaming sin configuración de ventanas.

**Solución:**
En `dataflow-pipeline/pipeline.py`, comentar o eliminar la sección de backup a Cloud Storage:

```python
# Comentado - WriteToText requiere configuración adicional para streaming
# _ = (
#     validated_data
#     | 'Format for Cloud Storage' >> beam.ParDo(FormatForCloudStorage())
#     | 'Write to Cloud Storage' >> beam.io.WriteToText(...)
# )
```

### Error: Missing required option: project/region en Dataflow

**Síntoma:**
```
ValueError: Pipeline has validations errors:
Missing required option: project.
Missing required option: region.
```

**Solución:**
Agregar las opciones de Google Cloud al pipeline (ya incluido en `pipeline.py`):

```python
from apache_beam.options.pipeline_options import GoogleCloudOptions

known_args, pipeline_args = parser.parse_known_args(argv)
pipeline_options = PipelineOptions(pipeline_args)

# Agregar project y region explícitamente
google_cloud_options = pipeline_options.view_as(GoogleCloudOptions)
google_cloud_options.project = known_args.project
google_cloud_options.region = known_args.region
```

### Warnings de Pub/Sub con Dataflow (NO críticos)

**Advertencias esperadas:**
```
WARNING: Pub/Sub subscription has a dead letter policy configured,
which will not work as expected when Dataflow pulls from the subscription.

WARNING: Pub/Sub subscription has a retry policy configured,
which will not work as expected when Dataflow pulls from the subscription.
```

**Explicación:**
Estas advertencias son esperadas. Dataflow maneja su propio sistema de reintentos y dead-letter cuando consume de Pub/Sub. Las políticas configuradas en la suscripción no se aplican.

**No requiere acción** - El pipeline funciona correctamente con estas advertencias.

### Verificar estado del deployment

**Comando rápido:**
```bash
make status
```

**Verificación manual:**
```bash
# Ver jobs de Dataflow activos
gcloud dataflow jobs list --region=us-central1 --status=active

# Ver logs de Cloud Functions
gcloud functions logs read alert-processor --gen2 --region=us-central1 --limit=10

# Consultar datos en BigQuery
bq query --use_legacy_sql=false \
  'SELECT * FROM `PROJECT.sensor_data.raw_readings` LIMIT 10'
```

### Problemas de conectividad del dispositivo Arduino

**Error HTTP 401/403:**
- Verificar que la API Key sea correcta
- Confirmar que la API está habilitada: `apikeys.googleapis.com`
- Revisar restricciones de la API Key (solo debe permitir `pubsub.googleapis.com`)

**Error de certificado SSL:**
- Asegurar que ESP32 tenga actualizado el certificado root de Google
- Verificar que se use HTTPS (no HTTP)

**Timeout de conexión:**
- Verificar conectividad WiFi
- Confirmar que el PROJECT_ID y TOPIC_NAME sean correctos
- Revisar la URL completa: `https://pubsub.googleapis.com/v1/projects/{PROJECT}/topics/{TOPIC}:publish`

## Equipo

[Agregar nombres de integrantes del equipo]

## Licencia

MIT License

## Referencias

- [Cloud Pub/Sub Documentation](https://cloud.google.com/pubsub/docs)
- [Pub/Sub REST API](https://cloud.google.com/pubsub/docs/reference/rest)
- [API Keys Best Practices](https://cloud.google.com/docs/authentication/api-keys)
- [Apache Beam Programming Guide](https://beam.apache.org/documentation/programming-guide/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
