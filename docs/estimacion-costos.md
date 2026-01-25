# Estimación de Costos Mensuales - Sistema IoT de Monitoreo de Calidad de Aguas

**Fecha:** 20 de enero de 2026  
**Proyecto:** potent-odyssey-480320-k4  
**Región:** us-central1

---

## 📊 Volumen de Datos Observado

### Configuración Actual
- **Sensores activos:** 1 sensor (Arduino + DHT11 + ESP32)
- **Frecuencia de envío:** 1 mensaje cada 30 segundos
- **Tamaño promedio por mensaje:** ~300 bytes

### Cálculos de Volumen

```
Mensajes por minuto:  2 mensajes
Mensajes por hora:    120 mensajes
Mensajes por día:     2,880 mensajes
Mensajes por mes:     86,400 mensajes

Volumen de datos:
- Por mensaje: 300 bytes
- Por día: 2,880 × 300 bytes = 864 KB
- Por mes: 86,400 × 300 bytes = 25.92 MB (~26 MB)
```

### Estructura del Mensaje

```json
{
  "device_id": "sensor-001",
  "timestamp": "2026-01-20T23:39:38Z",
  "temperature": 26.2,
  "humidity": 47.0,
  "location": "Rio Principal, Santiago",
  "latitude": -33.4489,
  "longitude": -70.6693,
  "message_count": 46,
  "rssi": -70
}
```

---

## 💵 Desglose Detallado de Costos

### 1. Cloud Pub/Sub 💬

**Uso:**
- Mensajes publicados: 86,400/mes
- Mensajes entregados: 259,200/mes (3 suscripciones)
- Volumen total: ~78 MB/mes

**Pricing:**
- Primeros 10 GB/mes: **GRATIS**
- Siguientes TB: $40/TB

**Costo Mensual:** `$0.00` ✅ (Dentro de free tier)

---

### 2. Cloud Dataflow 🔄

**Configuración Actual:**
- Tipo de worker: `n1-standard-2`
  - 2 vCPU
  - 7.5 GB RAM
- Workers activos: 1 (promedio)
- Modo: Streaming (24/7)
- Auto-scaling: 1-5 workers

**Uso:**
- Horas por mes: 24 hrs × 30 días = 720 horas
- vCPU-horas: 720 × 2 = 1,440 vCPU-horas
- GB-RAM-horas: 720 × 7.5 = 5,400 GB-horas

**Pricing:**
- vCPU: $0.056/vCPU-hora
- RAM: $0.003557/GB-hora

**Cálculo:**
```
Mensajes mensuales: 8,640,000
Costo: 8,640 × $0.000040 = $0.35/mes
```

**Ahorro vs IoT Core**: ~$4.65/mes (93% reducción)
Costo MQTT: 8,640,000 × $0.000045 = $388.80/mes
```

**Optimización:**
- Usar batch de lecturas (enviar cada 60s con 2 lecturas)
- Costo optimizado: $194.40/mes

**Costo Final: ~$5/mes** (con tier gratuito de GCP: 250M mensajes gratis)

---

### 2. Cloud Pub/Sub

**Pricing:**
- Message ingestion: $40 por TiB
- Message delivery: $40 por TiB
- Storage (>24h): $0.27 per GiB/mes

**Cálculo:**
```
Volumen mensual: 1.73 GB = 0.00169 TiB

Ingestion: 0.00169 × $40 = $0.0676
Delivery (3 subscriptions):
  - Dataflow: 0.00169 × $40 = $0.0676
  - Alert Function: 0.00169 × $40 = $0.0676
  - Realtime Function: 0.00169 × $40 = $0.0676
  
Total delivery: $0.2028

Storage (retención 7 días): 0.4 GB × $0.27 = $0.108
```

**Costo Total Pub/Sub: $0.38/mes**

**Nota:** Los primeros 10 GB/mes son gratuitos, por lo que el costo real es $0.

---

### 3. Cloud Dataflow

**Pricing:**
- vCPU: $0.056 por vCPU-hora
- Memory: $0.003557 por GB-hora
- PD Storage: $0.000054 por GB-hora

**Configuración:**
- Machine type: n1-standard-2 (2 vCPUs, 7.5 GB RAM)
- Workers: 2-10 (promedio: 3)
- Horas de operación: 730/mes (24/7)

**Cálculo:**
```
Por worker por hora:
- vCPU: 2 × $0.056 = $0.112
- RAM: 7.5 × $0.003557 = $0.0267
- Storage (25 GB): 25 × $0.000054 = $0.00135
Total por worker-hora: $0.14

Workers promedio: 3
Horas mensuales: 730
Costo mensual: 3 × 730 × $0.14 = $306.60
```

**Optimización:**
- Usar Dataflow Flex Templates
- Scale down en horas de baja carga
- Usar Preemptible VMs (descuento 80%)

**Costo Optimizado: ~$100/mes**

---

### 4. BigQuery

**Pricing:**
- Storage: $0.020 per GB/mes (active)
- Storage: $0.010 per GB/mes (long-term, >90 días)
- Queries: $5 per TB scanned
- Streaming inserts: $0.010 per 200 MB

**Cálculo Storage:**
```
Datos raw:
- Año 1: 20.7 GB × $0.020 = $0.414/mes

Datos agregados (estimado 10% del raw):
- Año 1: 2.07 GB × $0.020 = $0.041/mes

Total storage (primer año): $0.46/mes
Total storage (con 365 días): $7.50/mes
```

**Cálculo Streaming Inserts:**
```
Volumen mensual: 1.73 GB
Bloques de 200 MB: 9 bloques
Costo: 9 × $0.010 = $0.09/mes
```

**Cálculo Queries:**
```
Queries diarias estimadas:
- Dashboard refresh: 100 queries × 10 MB = 1 GB/día
- Análisis ad-hoc: 10 queries × 100 MB = 1 GB/día
Total mensual scanned: 60 GB = 0.06 TB

Costo: 0.06 × $5 = $0.30/mes
```

**Costo Total BigQuery: $8/mes**

---

### 5. Cloud Storage

**Pricing:**
- Standard storage: $0.020 per GB/mes
- Nearline storage: $0.010 per GB/mes
- Coldline storage: $0.004 per GB/mes
- Archive storage: $0.0012 per GB/mes

**Cálculo:**
```
Backup de datos raw:
- Mes 1: 1.73 GB × $0.020 = $0.0346
- Mes 2-12: 20.7 GB promedio × $0.020 = $0.414/mes

Lifecycle policy aplicada:
- 0-90 días: Standard ($0.020)
- 91-365 días: Nearline ($0.010)
- 366-730 días: Coldline ($0.004)

Costo promedio año 1: $0.35/mes
```

**Operations:**
- Class A (writes): 288,000/día × 30 = 8,640,000 ops/mes
- Primeras 50,000 gratis, resto: $0.05 per 10,000
- Costo: 8,590,000 / 10,000 × $0.05 = $42.95/mes

**Costo Total Cloud Storage: $43/mes**

**Optimización:**
- Agrupar escrituras en archivos más grandes (hourly en vez de por mensaje)
- Costo optimizado: $2/mes

---

### 6. Firestore

**Pricing:**
- Document writes: $0.18 per 100K
- Document reads: $0.06 per 100K
- Document deletes: $0.02 per 100K
- Storage: $0.18 per GiB/mes

**Cálculo:**
```
Writes:
- Current readings: 8,640,000/mes = $15.55
- Device updates: 8,640,000/mes = $15.55
- Alerts (estimado 1% de lecturas): 86,400/mes = $0.16
Total writes: $31.26/mes

Reads (estimado 10× writes para dashboard):
- 86,400,000/mes = $51.84/mes

Storage:
- 100 devices × 10 KB = 1 MB
- 8,640,000 readings × 500 bytes = 4.3 GB
- Alertas: 100 MB
Total: 4.4 GB × $0.18 = $0.79/mes
```

**Costo Total Firestore: $83.89/mes**

**Optimización:**
- Implementar caché en client-side
- Usar listeners en lugar de polling
- Limpiar lecturas antiguas (> 24h)
- Costo optimizado: $5/mes

---

### 7. Cloud Functions

**Pricing:**
- Invocations: $0.40 per million
- Compute time: $0.0000025 per GB-second
- Networking: $0.12 per GB

**Configuración:**
- Memory: 256 MB
- Duration promedio: 200ms

**Cálculo Alert Processor:**
```
Invocations: 8,640,000/mes
Costo invocations: 8.64 × $0.40 = $3.46

Compute time:
- GB-seconds: 8,640,000 × 0.2s × 0.256GB = 442,368 GB-s
- Costo: 442,368 × $0.0000025 = $1.11

Total Alert Processor: $4.57/mes
```

**Cálculo Realtime Updater:**
```
Similar a Alert Processor: $4.57/mes
```

**Costo Total Cloud Functions: $9.14/mes**

**Nota:** Primeros 2M invocations y 400K GB-s son gratis mensualmente.  
**Costo real: $0/mes** (dentro del tier gratuito)

---

### 8. Cloud Logging

**Pricing:**
- Primeros 50 GB/mes: Gratis
- Adicionales: $0.50 per GB

**Cálculo:**
```
Logs generados:
- IoT Core: 8,640,000 × 100 bytes = 864 MB
- Dataflow: 10 GB/mes (logs de processing)
- Cloud Functions: 8,640,000 × 200 bytes = 1.73 GB
- BigQuery: 1 GB/mes
Total: ~14 GB/mes
```

**Costo Total Logging: $0/mes** (dentro de tier gratuito)

---

### 9. Cloud Monitoring

**Pricing:**
- Primeros 150 MB de métricas: Gratis
- Métricas adicionales: $0.258 per MB
- Logs-based metrics: $0.50 per GB

**Cálculo:**
```
Métricas del sistema: ~50 MB/mes
```

**Costo Total Monitoring: $0/mes** (dentro de tier gratuito)

---

### 10. Secret Manager

**Pricing:**
- Active secret versions: $0.06 per version/mes
- Access operations: $0.03 per 10K operations

**Cálculo:**
```
Secrets: 1 (SendGrid API key)
Accesses: 8,640,000 (por cada alert function call)

Costo storage: 1 × $0.06 = $0.06
Costo accesses: 864 × $0.03 = $25.92
```

**Costo Total Secret Manager: $25.98/mes**

**Optimización:**
- Cachear secret en Cloud Function (válido 5 minutos)
- Accesses reducidos a ~20,000/mes
- Costo optimizado: $0.12/mes

---

## Resumen de Costos Mensuales

### Escenario Base: 100 Sensores

| Servicio | Costo Sin Optimizar | Costo Optimizado | Notas |
|----------|---------------------|------------------|-------|
| Cloud IoT Core | $5.00 | $5.00 | Dentro de tier gratuito |
| Cloud Pub/Sub | $0.38 | $0.00 | Tier gratuito 10 GB |
| Cloud Dataflow | $306.60 | $100.00 | Preemptible VMs, scale down |
| BigQuery | $8.00 | $8.00 | - |
| Cloud Storage | $43.00 | $2.00 | Batch writes |
| Firestore | $83.89 | $5.00 | Caché, cleanup |
| Cloud Functions | $9.14 | $0.00 | Tier gratuito |
| Cloud Logging | $0.00 | $0.00 | Tier gratuito |
| Cloud Monitoring | $0.00 | $0.00 | Tier gratuito |
| Secret Manager | $25.98 | $0.12 | Caché de secrets |
| **TOTAL** | **$481.99/mes** | **$120.12/mes** | **75% ahorro** |

**Costo por Sensor: $1.20/mes**

---

## Escalabilidad de Costos

### Escenario: 10 Sensores

| Servicio | Costo Mensual |
|----------|---------------|
| Cloud IoT Core | $0.00 (tier gratuito) |
| Cloud Pub/Sub | $0.00 |
| Cloud Dataflow | $50.00 (1 worker) |
| BigQuery | $2.00 |
| Cloud Storage | $0.50 |
| Firestore | $1.00 |
| Cloud Functions | $0.00 |
| Otros | $0.00 |
| **TOTAL** | **$53.50/mes** |

**Costo por Sensor: $5.35/mes**

---

### Escenario: 1,000 Sensores

| Servicio | Costo Mensual |
|----------|---------------|
| Cloud IoT Core | $50.00 |
| Cloud Pub/Sub | $3.00 |
| Cloud Dataflow | $400.00 (10 workers) |
| BigQuery | $50.00 |
| Cloud Storage | $15.00 |
| Firestore | $50.00 |
| Cloud Functions | $10.00 |
| Otros | $2.00 |
| **TOTAL** | **$580.00/mes** |

**Costo por Sensor: $0.58/mes**

---

## Comparación con Soluciones Alternativas

### Alternativa 1: Infraestructura On-Premises

| Componente | Costo Inicial | Costo Mensual |
|------------|---------------|---------------|
| Servidor (4 cores, 16GB RAM) | $2,000 | $50 (energía, cooling) |
| Storage (2 TB RAID) | $500 | $10 |
| Networking | $300 | $100 (internet) |
| Personal (0.5 DevOps) | - | $3,000 |
| Mantenimiento | - | $500 |
| **TOTAL** | **$2,800** | **$3,660/mes** |

**ROI GCP:** Ahorro de $3,540/mes = **96.7% de reducción de costos**

---

### Alternativa 2: AWS IoT

| Servicio AWS | Equivalente GCP | Costo AWS | Costo GCP | Diferencia |
|--------------|-----------------|-----------|-----------|------------|
| AWS IoT Core | Cloud IoT Core | $8.00 | $5.00 | -37.5% |
| Kinesis Streams | Cloud Pub/Sub | $25.00 | $0.00 | -100% |
| Lambda | Cloud Functions | $15.00 | $0.00 | -100% |
| Kinesis Firehose | Cloud Dataflow | $30.00 | $100.00 | +233% |
| S3 | Cloud Storage | $2.00 | $2.00 | 0% |
| Athena | BigQuery | $5.00 | $8.00 | +60% |
| DynamoDB | Firestore | $25.00 | $5.00 | -80% |
| **TOTAL** | - | **$110/mes** | **$120/mes** | **+9%** |

**Conclusión:** Costos similares entre GCP y AWS. GCP ligeramente más caro pero con mejores integraciones.

---

### Alternativa 3: Azure IoT

| Servicio Azure | Costo Azure | Costo GCP | Diferencia |
|----------------|-------------|-----------|------------|
| IoT Hub | $25.00 | $5.00 | -80% |
| Event Hubs | $20.00 | $0.00 | -100% |
| Stream Analytics | $150.00 | $100.00 | -33% |
| Blob Storage | $2.00 | $2.00 | 0% |
| Cosmos DB | $50.00 | $5.00 | -90% |
| **TOTAL** | **$247/mes** | **$120/mes** | **-51%** |

**Conclusión:** GCP es 51% más barato que Azure para este workload.

---

## Proyección de Costos a 3 Años

### 100 Sensores

| Año | Storage Acumulado | Costo Mensual | Costo Anual |
|-----|-------------------|---------------|-------------|
| 1 | 20 GB | $120 | $1,440 |
| 2 | 40 GB | $125 | $1,500 |
| 3 | 60 GB | $130 | $1,560 |
| **Total 3 años** | - | - | **$4,500** |

### 1,000 Sensores

| Año | Storage Acumulado | Costo Mensual | Costo Anual |
|-----|-------------------|---------------|-------------|
| 1 | 200 GB | $580 | $6,960 |
| 2 | 400 GB | $620 | $7,440 |
| 3 | 600 GB | $660 | $7,920 |
| **Total 3 años** | - | - | **$22,320** |

---

## Optimizaciones Adicionales

### 1. Committed Use Discounts (CUD)

- **Dataflow (Compute Engine)**: 1-year commitment = 25% descuento
- **BigQuery**: Flat-rate pricing para queries predecibles
- **Ahorro estimado**: 20-30% en costos de compute

### 2. Sustained Use Discounts (SUD)

- Automático para recursos que corren >25% del mes
- Dataflow: ~30% descuento por uso continuo
- **Ahorro estimado**: $30/mes

### 3. Preemptible VMs para Dataflow

- 80% más baratos que VMs regulares
- Adecuados para procesamiento de stream con checkpointing
- **Ahorro estimado**: $200/mes

### 4. Lifecycle Policies en Storage

```
Implementado:
- 0-90 días: Standard
- 91-365 días: Nearline (50% descuento)
- 366+ días: Coldline (80% descuento)

Ahorro año 2-3: $50-100/mes
```

### 5. Query Optimization en BigQuery

- Usar tablas particionadas (reducir data scanned)
- Clustering por device_id
- Materializar vistas frecuentes
- **Ahorro estimado**: 40-60% en costos de queries

---

## Presupuesto Recomendado

### Ambiente de Desarrollo

| Componente | Costo Mensual |
|------------|---------------|
| 10 sensores de prueba | $53.50 |
| **Total Dev** | **$53.50/mes** |

### Ambiente de Producción

| Escenario | Sensores | Costo Mensual | Buffer (20%) | **Total** |
|-----------|----------|---------------|--------------|-----------|
| Piloto | 10 | $53.50 | $10.70 | **$64.20** |
| Pequeño | 50 | $95.00 | $19.00 | **$114.00** |
| Mediano | 100 | $120.00 | $24.00 | **$144.00** |
| Grande | 500 | $400.00 | $80.00 | **$480.00** |
| Enterprise | 1,000 | $580.00 | $116.00 | **$696.00** |

**Recomendación:** Empezar con piloto de 10 sensores ($64/mes) y escalar gradualmente.

---

## Monitoreo de Costos

### Alertas Recomendadas

1. **Budget Alert al 50%**: Cuando gastos excedan $60/mes (100 sensores)
2. **Budget Alert al 80%**: Cuando gastos excedan $96/mes
3. **Budget Alert al 100%**: Cuando gastos excedan $120/mes
4. **Anomaly Detection**: Incremento >20% día a día

### Dashboards de Cost Management

- Vista por servicio
- Vista por proyecto
- Tendencias mensuales
- Proyecciones basadas en uso actual

---

## Conclusión de Costos

### Resumen Ejecutivo

- **Costo por sensor (100 sensores)**: $1.20/mes
- **Costo total sistema (100 sensores)**: $120/mes
- **ROI vs On-premises**: 96.7% de ahorro
- **Escalabilidad**: Costo por sensor disminuye con escala
- **Predictibilidad**: 90% de costos son predecibles

### Factores de Costo Principales

1. **Cloud Dataflow**: 83% del costo total
2. **BigQuery**: 7% del costo total
3. **Cloud IoT Core**: 4% del costo total
4. **Firestore**: 4% del costo total
5. **Otros**: 2% del costo total

### Recomendaciones Finales

✅ Implementar todas las optimizaciones mencionadas  
✅ Empezar con piloto de 10-50 sensores  
✅ Monitorear costos semanalmente en fase inicial  
✅ Activar CUD después de 3 meses de operación estable  
✅ Revisar y ajustar umbrales de auto-scaling mensualmente
