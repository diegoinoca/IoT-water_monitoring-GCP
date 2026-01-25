# Análisis Comparativo de Alternativas Tecnológicas

## 1. Protocolos de Comunicación IoT

### 1.1 Comparación: MQTT vs HTTP/REST vs gRPC

| Criterio | MQTT | HTTP/REST | gRPC | Decisión |
|----------|------|-----------|------|----------|
| **Overhead de Protocol** | Muy bajo (~2 bytes header) | Alto (~200+ bytes header) | Medio (~50 bytes) | ✅ MQTT |
| **Consumo de Batería** | Excelente (keep-alive) | Malo (conexión por request) | Bueno | ✅ MQTT |
| **Latencia** | Muy baja (< 10ms) | Media (50-100ms) | Baja (20-50ms) | ✅ MQTT |
| **Ancho de Banda** | Mínimo (5-10 KB/día) | Alto (50-100 KB/día) | Medio (20-40 KB/día) | ✅ MQTT |
| **QoS Levels** | 0, 1, 2 (garantías de entrega) | No nativo | No nativo | ✅ MQTT |
| **Bidireccionalidad** | Sí (pub/sub nativo) | No (polling requerido) | Sí (streaming) | ✅ MQTT |
| **Complejidad Cliente** | Baja | Media | Alta | ✅ MQTT |
| **Soporte en Arduino** | Excelente (PubSubClient) | Bueno | Limitado | ✅ MQTT |
| **Firewall Friendly** | Medio (puerto 8883) | Alto (puerto 443) | Medio | HTTP |
| **Debugging** | Medio | Fácil (curl, Postman) | Medio | HTTP |

**Justificación de la Elección: MQTT**

MQTT es el protocolo óptimo para dispositivos IoT con recursos limitados porque:

1. **Eficiencia**: Header de solo 2 bytes vs 200+ de HTTP
2. **Batería**: Conexión persistente con keep-alive reduce consumo en 80%
3. **Resiliencia**: QoS levels garantizan entrega de mensajes críticos
4. **Pub/Sub nativo**: Desacoplamiento natural entre sensores y procesamiento
5. **Estándar IoT**: Ampliamente adoptado en la industria

**Caso de Uso Específico:**
```
Sensor DHT11 envía lectura cada 30 segundos:
- MQTT: 200 bytes/mensaje × 2,880 mensajes/día = 576 KB/día
- HTTP: 800 bytes/mensaje × 2,880 mensajes/día = 2.3 MB/día
  
Ahorro de ancho de banda: 75%
Ahorro de batería: ~70%
```

---

### 1.2 Comparación: Cloud Pub/Sub vs Apache Kafka vs RabbitMQ vs AWS IoT

| Criterio | Cloud Pub/Sub | Apache Kafka | RabbitMQ | AWS IoT | Decisión |
|----------|---------------|--------------|----------|---------|----------|
| **Gestión** | Completamente gestionado | Self-managed | Self-managed | Completamente gestionado | ✅ Pub/Sub |
| **Escalabilidad** | Automática e ilimitada | Manual | Manual | Automática | ✅ Pub/Sub |
| **Latencia** | < 100ms | < 10ms | < 50ms | < 100ms | Kafka (pero... |
| **Durabilidad** | 7 días por defecto | Configurable | Configurable | 7 días | ✅ Pub/Sub |
| **Costo Operativo** | Bajo (pay-per-use) | Alto (VMs, ops) | Medio (VMs) | Medio | ✅ Pub/Sub |
| **Integración GCP** | Nativa | Requiere conectores | Requiere conectores | No aplica | ✅ Pub/Sub |
| **Throughput** | 1M+ msg/s | 1M+ msg/s | 50K msg/s | 500K msg/s | ✅ Pub/Sub |
| **Ordenamiento** | Por key | Por partición | Por queue | Por topic | Kafka |
| **Retries Automáticos** | Sí (con backoff) | No (manual) | Sí (limitado) | Sí | ✅ Pub/Sub |
| **Dead Letter Queue** | Sí (nativo) | No (manual) | Sí (plugin) | Sí | ✅ Pub/Sub |
| **Multi-tenancy** | Excelente | Medio | Bueno | Excelente | ✅ Pub/Sub |
| **Costo Mensual (100 sensores)** | $10 | $150+ | $100+ | $15 | ✅ Pub/Sub |

**Justificación de la Elección: Cloud Pub/Sub**

1. **Cero Operaciones**: No requiere provisionar, parchear o escalar infrastructure
2. **Escalamiento Automático**: De 0 a millones de mensajes sin configuración
3. **Integración Nativa**: Conecta directamente con IoT Core, Dataflow, Functions
4. **Confiabilidad**: SLA 99.95% con replicación multi-zona automática
5. **Costo-Efectividad**: Solo pagas por lo que usas, sin costos de infraestructura

**Trade-off Aceptado:**
- Kafka tiene menor latencia (10ms vs 100ms), pero para nuestro caso con lecturas cada 30 segundos, 100ms adicionales son insignificantes
- El ahorro en costos operativos ($140/mes) y tiempo de gestión justifica ampliamente la elección

---

## 2. Almacenamiento de Datos

### 2.1 Comparación: Almacenamiento de Objetos

| Criterio | Cloud Storage | Persistent Disk | Filestore | Decisión |
|----------|---------------|-----------------|-----------|----------|
| **Caso de Uso** | Archivos inmutables | Block storage | File shares NFS | Backup raw data |
| **Escalabilidad** | Ilimitada | Hasta 64 TB | Hasta 100 TB | ✅ Cloud Storage |
| **Costo (1 TB/mes)** | $20 (Standard) | $170 (SSD) | $200 | ✅ Cloud Storage |
| **Durabilidad** | 99.999999999% (11 9's) | 99.99% | 99.99% | ✅ Cloud Storage |
| **Latency** | 10-50ms | < 1ms | 1-10ms | Persistent Disk |
| **IOPS** | 1,000-5,000 | 30,000+ | 10,000 | Persistent Disk |
| **Acceso Concurrente** | Ilimitado | Limitado | Bueno | ✅ Cloud Storage |
| **Lifecycle Policies** | Sí (automáticas) | No | No | ✅ Cloud Storage |
| **Versionado** | Sí | No | No | ✅ Cloud Storage |

**Justificación: Cloud Storage para Backup**

Para almacenar copias de respaldo de datos raw:
- **Inmutabilidad**: Los datos históricos no se modifican
- **Escala**: Crecimiento ilimitado sin re-provisionar
- **Costo**: 10x más barato que Persistent Disk
- **Lifecycle**: Auto-migración a clases más baratas (Nearline, Coldline)

**Política de Lifecycle Implementada:**
```
Día 0-90:     Standard Storage ($20/TB)
Día 91-365:   Nearline ($10/TB)
Día 366-730:  Coldline ($4/TB)
Día 731+:     Archive ($1.2/TB)
```

---

### 2.2 Comparación: Bases de Datos para Analytics

| Criterio | BigQuery | Cloud SQL | Bigtable | Snowflake | Decisión |
|----------|----------|-----------|----------|-----------|----------|
| **Arquitectura** | Columnar MPP | Relacional | NoSQL wide-column | Columnar MPP | Analytics |
| **Escalabilidad** | Petabytes | Hasta 64 TB | Petabytes | Petabytes | ✅ BigQuery |
| **Costo Queries (1 TB)** | $5 | N/A (compute) | N/A (throughput) | $40 | ✅ BigQuery |
| **Costo Storage (1 TB)** | $20/mes | $180/mes | $170/mes | $23/mes | ✅ BigQuery |
| **Latencia Queries** | 1-10 segundos | < 1 segundo | < 10ms | 2-15 segundos | Cloud SQL |
| **Queries SQL** | Standard SQL | Standard SQL | No SQL | Standard SQL | SQL |
| **Time Travel** | 7 días | No | No | 90 días | ✅ BigQuery |
| **Particionamiento** | Sí (automático) | Manual | Sí (row key) | Sí (micro-particiones) | ✅ BigQuery |
| **Streaming Inserts** | Sí (nativo) | Sí (limitado) | Sí (excelente) | Sí | BigQuery/Bigtable |
| **Administración** | Cero (serverless) | Alto (DB admin) | Medio | Bajo | ✅ BigQuery |
| **Agregaciones** | Excelente | Bueno | Manual | Excelente | ✅ BigQuery |

**Justificación: BigQuery para Analytics**

1. **Serverless**: No requiere provisionar o dimensionar clusters
2. **Costo-Efectivo**: Solo pagas por TB scaneados, sin servidores idle
3. **SQL Estándar**: Queries familiares para analistas
4. **Integración**: Nativo con Dataflow, Looker Studio, Data Studio
5. **Escalamiento**: Procesa petabytes sin intervención

**Caso de Uso:**
```sql
-- Query de agregación diaria para 1 año de datos
SELECT 
  DATE(timestamp) as date,
  device_id,
  AVG(temperature) as avg_temp,
  AVG(humidity) as avg_humidity
FROM `project.sensor_data.raw_readings`
WHERE timestamp BETWEEN '2025-01-01' AND '2026-01-01'
GROUP BY date, device_id

Datos escaneados: 20 GB
Costo: $0.10
Tiempo: ~3 segundos
```

**Por qué NO Cloud SQL:**
- Requiere provisionar instancia (mínimo $50/mes)
- No escala bien para queries analíticos de GB/TB
- Requiere tuning manual de índices y particiones
- Limitado a 64 TB (insuficiente para crecimiento a largo plazo)

**Por qué NO Bigtable:**
- No soporta SQL (requiere programación compleja)
- Optimizado para low-latency reads (< 10ms), no analytics
- Más caro: $170/TB vs $20/TB de BigQuery
- Requiere diseño cuidadoso de row key (complejidad adicional)

---

### 2.3 Comparación: Bases de Datos para Tiempo Real

| Criterio | Firestore | Realtime Database | Bigtable | Redis | Decisión |
|----------|-----------|-------------------|----------|-------|----------|
| **Modelo de Datos** | Documentos (NoSQL) | JSON tree | Wide-column | Key-Value | Documentos |
| **Latencia Reads** | < 50ms | < 50ms | < 10ms | < 1ms | Bigtable/Redis |
| **Latencia Writes** | < 100ms | < 100ms | < 10ms | < 1ms | Aceptable |
| **Queries** | Sí (índices) | Limitado | No | No | ✅ Firestore |
| **Real-time Listeners** | Sí (WebSocket) | Sí (WebSocket) | No | Pub/Sub | ✅ Firestore |
| **Escalabilidad** | Automática | Limitada (1 DB) | Ilimitada | Limitada | Firestore/Bigtable |
| **Costo (100K docs)** | $0.18/mes | $5/mes | $0.17/mes | $15/mes | ✅ Firestore |
| **Offline Support** | Sí (SDK) | Sí (SDK) | No | No | ✅ Firestore |
| **Multi-region** | Sí | No | Sí | Manual | ✅ Firestore |
| **Transacciones** | Sí (ACID) | Limitado | Sí | Limitado | ✅ Firestore |

**Justificación: Firestore para Tiempo Real**

1. **Real-time Sync**: Listeners automáticos para actualizaciones en vivo
2. **Queries Flexibles**: Índices permiten consultas complejas
3. **Offline Support**: SDK sincroniza automáticamente cuando vuelve online
4. **Escalamiento Automático**: Sin necesidad de sharding manual
5. **Integración Mobile/Web**: SDKs nativos para todas las plataformas

**Caso de Uso:**
```javascript
// Escuchar cambios en tiempo real desde web app
db.collection('current_readings')
  .where('device_id', '==', 'sensor-001')
  .onSnapshot((snapshot) => {
    snapshot.docChanges().forEach((change) => {
      if (change.type === 'modified') {
        updateDashboard(change.doc.data());
      }
    });
  });
```

**Por qué NO Realtime Database:**
- Limitado a una sola instancia (no escala horizontalmente)
- Modelo de datos JSON tree menos flexible que documentos
- Queries muy limitadas (requiere denormalización)

**Por qué NO Bigtable:**
- No soporta real-time listeners (requiere polling)
- Sin soporte para queries (solo lookups por key)
- Sobreprecio para < 1 TB de datos

**Por qué NO Redis:**
- Requiere gestión de infraestructura (Memorystore)
- No tiene persistencia durable por defecto
- Costo más alto para uso de baja frecuencia

---

## 3. Procesamiento de Datos

### 3.1 Comparación: Procesamiento por Lotes

| Criterio | Dataflow (Batch) | Dataproc (Spark) | Cloud Composer (Airflow) | Decisión |
|----------|------------------|------------------|--------------------------|----------|
| **Modelo** | Apache Beam | Apache Spark | Workflow orchestration | - |
| **Lenguaje** | Python, Java | Python, Scala, Java | Python (DAGs) | Python |
| **Gestión** | Serverless | Semi-managed | Managed | ✅ Dataflow |
| **Auto-scaling** | Automático | Manual | N/A | ✅ Dataflow |
| **Costo Idle** | $0 | Alto (cluster) | Medio | ✅ Dataflow |
| **Latencia Start** | 2-5 min | 5-10 min | N/A | ✅ Dataflow |
| **Unified API** | Batch + Stream | Separado | N/A | ✅ Dataflow |
| **Integración GCP** | Nativa | Buena | Excelente | Dataflow |

**Nota:** Nuestro caso usa principalmente streaming, pero Dataflow permite unified batch/stream.

---

### 3.2 Comparación: Procesamiento en Stream

| Criterio | Dataflow | Pub/Sub + Functions | Apache Flink | Spark Streaming | Decisión |
|----------|----------|---------------------|--------------|-----------------|----------|
| **Latencia** | Segundos | Sub-segundo | Milisegundos | Segundos | Functions (pero... |
| **Windowing** | Avanzado (Beam) | Manual | Avanzado | Limitado | ✅ Dataflow |
| **State Management** | Managed | Manual | Managed | Managed | ✅ Dataflow |
| **Exactamente-once** | Sí | No (at-least-once) | Sí | Sí | Dataflow |
| **Complejidad** | Media | Baja | Alta | Media | Functions |
| **Escalabilidad** | Automática | Automática | Manual | Manual | ✅ Dataflow |
| **Costo (100 sensores)** | $100/mes | $5/mes | $200/mes | $150/mes | Functions |
| **Gestión** | Serverless | Serverless | Self-managed | Self-managed | ✅ Dataflow |

**Justificación: Dataflow para Stream Processing**

Para nuestro caso elegimos **Dataflow** porque:

1. **Windowing Avanzado**: Necesitamos agregaciones por ventanas de 1 min, 5 min, 1 hora
2. **Exactly-Once**: Garantiza no duplicar métricas en BigQuery
3. **State Management**: Maneja estado de agregaciones automáticamente
4. **Unified Batch/Stream**: Un solo pipeline para ambos modos
5. **Auto-scaling**: Escala de 2 a 10 workers según carga

**Trade-off:**
- Cloud Functions es más barato ($5 vs $100/mes)
- PERO Dataflow ofrece garantías de exactly-once y windowing que Functions no tiene
- Para nuestro caso de agregaciones complejas, Dataflow es necesario

**Arquitectura Híbrida Implementada:**
```
Pub/Sub → Dataflow: Procesamiento con agregaciones (exactly-once)
Pub/Sub → Functions: Alertas simples (at-least-once es aceptable)
Pub/Sub → Functions: Actualizar Firestore
```

---

## 4. Resumen de Decisiones

| Componente | Tecnología Elegida | Alternativa Considerada | Razón Principal |
|------------|-------------------|-------------------------|-----------------|
| Protocolo IoT | **MQTT** | HTTP/REST | Eficiencia de batería y ancho de banda |
| Message Broker | **Cloud Pub/Sub** | Apache Kafka | Gestión cero y costo operativo |
| Analytics DB | **BigQuery** | Cloud SQL, Bigtable | Serverless y costo-efectivo para analytics |
| Real-time DB | **Firestore** | Realtime Database | Queries flexibles y real-time sync |
| Stream Processing | **Dataflow** | Cloud Functions | Windowing y exactly-once semantics |
| Backup Storage | **Cloud Storage** | Persistent Disk | Durabilidad y lifecycle management |
| Alerting | **Cloud Functions** | Dataflow | Simplicidad para lógica de alertas |
| IaC | **Terraform** | Deployment Manager | Multi-cloud y ecosistema maduro |

---

## 5. Patrones Arquitectónicos Aplicados

### 5.1 Lambda Architecture (Simplificada)

```
Batch Layer:  BigQuery (raw_readings, aggregations_hour, aggregations_day)
Stream Layer: Dataflow (aggregations_minute en tiempo real)
Serving Layer: Firestore (current_readings, última lectura por device)
```

### 5.2 CQRS (Command Query Responsibility Segregation)

```
Command Side (Escritura): IoT → Pub/Sub → Dataflow → BigQuery
Query Side (Lectura):     
  - Analytics: BigQuery (queries complejos)
  - Real-time: Firestore (lecturas rápidas)
```

### 5.3 Event-Driven Architecture

```
Eventos:
  - SensorReadingReceived → Dataflow, Functions
  - ThresholdExceeded → Alert Functions
  - DeviceRegistered → Firestore
  
Beneficios:
  - Desacoplamiento entre productores y consumidores
  - Escalabilidad independiente de componentes
  - Tolerancia a fallos (retry automático)
```

### 5.4 Saga Pattern (para Alertas)

```
1. Recibir lectura → 
2. Evaluar umbral → 
3. Si excedido: Guardar alerta en Firestore → 
4. Publicar a Alerts topic → 
5. Enviar email
   
Compensación: Si email falla, se reintenta; alerta queda registrada
```

---

[Continúa con estimación de costos...]
