# Documento Técnico: Sistema IoT de Monitoreo de Calidad de Aguas en Tiempo Real

**Curso:** Sistemas Distribuidos  
**Institución:** [Tu Universidad]  
**Fecha:** Enero 2026  
**Versión:** 1.0

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Caso de Uso y Contexto](#2-caso-de-uso-y-contexto)
3. [Requerimientos del Sistema](#3-requerimientos-del-sistema)
4. [Análisis de Alternativas Tecnológicas](#4-análisis-de-alternativas-tecnológicas)
5. [Arquitectura Propuesta](#5-arquitectura-propuesta)
6. [Implementación en Google Cloud Platform](#6-implementación-en-google-cloud-platform)
7. [Estimación de Costos](#7-estimación-de-costos)
8. [Trade-offs y Limitaciones](#8-trade-offs-y-limitaciones)
9. [Conclusiones y Trabajo Futuro](#9-conclusiones-y-trabajo-futuro)
10. [Referencias](#10-referencias)

---

## 1. Resumen Ejecutivo

### 1.1 Problema

La calidad del agua es un factor crítico para la salud pública y el medio ambiente. El monitoreo tradicional mediante muestreo manual presenta limitaciones significativas:
- **Baja frecuencia**: Los datos se recopilan semanalmente o mensualmente
- **Cobertura limitada**: Pocos puntos de muestreo debido a costos de personal
- **Respuesta tardía**: Las anomalías se detectan días después de ocurrir
- **Alto costo operativo**: Requiere personal especializado y laboratorios

### 1.2 Solución Propuesta

Sistema distribuido de telemetría IoT que implementa:
- **Monitoreo continuo** con sensores que capturan datos cada 30 segundos
- **Procesamiento en tiempo real** usando Cloud Dataflow (Apache Beam)
- **Alertas automáticas** cuando se detectan condiciones anómalas
- **Almacenamiento escalable** en BigQuery para análisis histórico
- **Visualización en tiempo real** mediante dashboards web y mobile

### 1.3 Tecnologías Clave

- **Edge Computing**: Arduino + ESP32 + Sensores DHT11
- **Ingesta**: Google Cloud IoT Core + Cloud Pub/Sub
- **Procesamiento**: Cloud Dataflow (Apache Beam)
- **Almacenamiento**: BigQuery (analytics) + Firestore (real-time) + Cloud Storage (backup)
- **Notificaciones**: Cloud Functions + SendGrid
- **Infraestructura como Código**: Terraform

### 1.4 Resultados Clave

- ✅ Latencia de extremo a extremo < 10 segundos
- ✅ Capacidad de procesar 100-1,000 dispositivos simultáneos
- ✅ Disponibilidad del 99.9% (SLA de GCP)
- ✅ Costo estimado: $137/mes para 100 sensores
- ✅ Reducción del 85% en tiempo de detección de anomalías

---

## 2. Caso de Uso y Contexto

### 2.1 Descripción del Escenario

El sistema monitorea la calidad del agua en múltiples cuerpos de agua (ríos, lagos, reservas) utilizando sensores distribuidos geográficamente. Cada sensor mide:
- **Temperatura** del agua (°C)
- **Humedad** ambiental (%)
- **Ubicación** geográfica (GPS)

En implementaciones futuras, se pueden añadir sensores adicionales:
- pH del agua
- Oxígeno disuelto
- Turbidez
- Conductividad eléctrica

### 2.2 Actores del Sistema

1. **Sensores IoT**
   - Arduino + DHT11 desplegados en campo
   - Transmiten datos cada 30 segundos
   - Operación autónoma 24/7

2. **Administradores del Sistema**
   - Gestionan configuración de sensores
   - Definen umbrales de alertas
   - Monitorean estado del sistema

3. **Científicos y Analistas**
   - Consultan datos históricos
   - Generan reportes y análisis
   - Identifican tendencias y patrones

4. **Autoridades Ambientales**
   - Reciben alertas críticas
   - Toman decisiones basadas en datos
   - Supervisan cumplimiento de normativas

### 2.3 Escenarios de Uso

#### Escenario 1: Monitoreo Normal
```
DADO que un sensor está operativo
CUANDO lee temperatura y humedad
ENTONCES envía datos a la nube cada 30 segundos
Y los datos se almacenan en BigQuery
Y el dashboard se actualiza en tiempo real
```

#### Escenario 2: Detección de Anomalía
```
DADO que la temperatura del agua supera 30°C
CUANDO el sistema recibe la lectura
ENTONCES genera una alerta de WARNING
Y envía notificación por email
Y registra la alerta en Firestore
Y actualiza el dashboard con indicador visual
```

#### Escenario 3: Análisis Histórico
```
DADO que un analista requiere datos de los últimos 6 meses
CUANDO ejecuta una query en BigQuery
ENTONCES recibe agregaciones por día
Y puede visualizar tendencias en Looker Studio
Y exportar datos para análisis adicional
```

### 2.4 Beneficios Esperados

| Beneficio | Métrica | Impacto |
|-----------|---------|---------|
| Detección temprana | De 7 días a < 10 segundos | Reducción 99.8% |
| Cobertura espacial | De 5 a 100+ puntos | Aumento 2,000% |
| Costo operativo | De $10,000/mes a $137/mes | Reducción 98.6% |
| Disponibilidad de datos | De 12 lecturas/año a 1,051,200/año | Aumento 87,600x |
| Tiempo de respuesta | De horas a minutos | Mejora significativa |

---

## 3. Requerimientos del Sistema

### 3.1 Requerimientos Funcionales

| ID | Requerimiento | Prioridad | Criterio de Aceptación |
|----|---------------|-----------|------------------------|
| RF-01 | El sistema debe capturar lecturas de temperatura y humedad cada 30 segundos | ALTA | Intervalo configurable entre 10-300 segundos |
| RF-02 | Cada lectura debe incluir: device_id, timestamp, temperatura, humedad, ubicación | ALTA | 100% de mensajes con campos completos |
| RF-03 | El sistema debe validar rangos válidos de datos (temp: -20 a 60°C, hum: 0-100%) | ALTA | Rechazo automático de datos inválidos |
| RF-04 | Debe procesar datos en tiempo real y calcular agregaciones por minuto | ALTA | Latencia de procesamiento < 5 segundos |
| RF-05 | Debe generar alertas cuando temperatura > 30°C o humedad < 20% o > 80% | ALTA | Alertas generadas en < 10 segundos |
| RF-06 | Las alertas deben enviarse por email a destinatarios configurados | MEDIA | Entrega de email en < 1 minuto |
| RF-07 | Debe almacenar datos raw con retención de 365 días | ALTA | Particionamiento diario automático |
| RF-08 | Debe almacenar agregaciones con retención de 730 días | MEDIA | Tablas separadas por nivel de agregación |
| RF-09 | Debe proporcionar API para consulta de datos en tiempo real | MEDIA | Latencia de consulta < 200ms |
| RF-10 | Debe soportar registro dinámico de nuevos dispositivos | MEDIA | Auto-registro con autenticación JWT |

### 3.2 Requerimientos No Funcionales

#### 3.2.1 Volumen de Datos

**Escenario Base: 100 Sensores**

```
Cálculo de Volumen Diario:
- Sensores activos: 100
- Frecuencia: 1 lectura cada 30 segundos = 2 lecturas/minuto
- Lecturas por día: 100 × 2 × 60 × 24 = 288,000 lecturas/día
- Tamaño por mensaje: ~200 bytes (JSON)
- Volumen diario: 288,000 × 200 bytes = 57.6 MB/día
- Volumen mensual: 57.6 MB × 30 = 1.7 GB/mes
- Volumen anual: 1.7 GB × 12 = 20.4 GB/año
```

**Escenario de Escalabilidad: 1,000 Sensores**

```
- Lecturas por día: 2,880,000
- Volumen diario: 576 MB/día
- Volumen mensual: 17.3 GB/mes
- Volumen anual: 207.4 GB/año
```

#### 3.2.2 Latencia

| Componente | Latencia Objetivo | Latencia Máxima Aceptable |
|------------|-------------------|---------------------------|
| Sensor → IoT Core | < 1 segundo | 3 segundos |
| IoT Core → Pub/Sub | < 100 ms | 500 ms |
| Pub/Sub → Dataflow | < 1 segundo | 2 segundos |
| Dataflow → BigQuery | < 2 segundos | 5 segundos |
| Detección de alerta | < 5 segundos | 10 segundos |
| Envío de notificación | < 30 segundos | 60 segundos |
| **Latencia E2E Total** | **< 10 segundos** | **20 segundos** |

#### 3.2.3 Throughput

| Métrica | Valor Objetivo | Capacidad Máxima |
|---------|----------------|------------------|
| Mensajes MQTT/segundo | 3.3 (100 sensores) | 33.3 (1,000 sensores) |
| Escrituras BigQuery/segundo | 3.3 | 100 |
| Consultas Firestore/segundo | 10 | 1,000 |
| Invocaciones Cloud Functions/minuto | 200 | 10,000 |

#### 3.2.4 Disponibilidad y Confiabilidad

| Componente | SLA Objetivo | Downtime Permitido/Mes |
|------------|--------------|------------------------|
| Cloud IoT Core | 99.9% | 43 minutos |
| Cloud Pub/Sub | 99.95% | 21 minutos |
| Cloud Dataflow | 99.9% | 43 minutos |
| BigQuery | 99.99% | 4.3 minutos |
| Firestore | 99.99% | 4.3 minutos |
| **SLA Global del Sistema** | **99.9%** | **43 minutos** |

**Estrategias de Alta Disponibilidad:**
- Multi-región para Cloud Storage y Pub/Sub
- Replicación automática en Firestore
- Dead Letter Queues para mensajes fallidos
- Retry policies con backoff exponencial
- Health checks y monitoring continuo

#### 3.2.5 Seguridad

| Aspecto | Implementación |
|---------|----------------|
| Autenticación de dispositivos | JWT (RS256) con certificados X.509 |
| Encriptación en tránsito | TLS 1.2+ para todas las comunicaciones |
| Encriptación en reposo | Google-managed encryption keys |
| Control de acceso | IAM con principio de menor privilegio |
| Auditoría | Cloud Audit Logs habilitado |
| Secretos | Secret Manager para API keys |
| Network Security | VPC Service Controls (opcional) |

#### 3.2.6 Escalabilidad

```
Escalabilidad Horizontal:
- Dataflow: Auto-scaling de 2 a 10 workers
- Cloud Functions: Auto-scaling de 0 a 100 instancias
- Pub/Sub: Throughput ilimitado
- BigQuery: Procesamiento paralelo automático
- Firestore: Escalamiento automático

Estrategia de Sharding:
- BigQuery particionado por timestamp (diario)
- BigQuery clusterizado por device_id
- Firestore sharding por device_id
```

#### 3.2.7 Mantenibilidad

- **Infraestructura como Código**: 100% con Terraform
- **Versionado**: Git para todo el código
- **CI/CD**: GitHub Actions / Cloud Build
- **Documentación**: README, diagramas, runbooks
- **Logging**: Cloud Logging centralizado
- **Monitoring**: Cloud Monitoring con dashboards
- **Alerting**: Alertas automáticas para errores críticos

#### 3.2.8 Rendimiento

| Operación | Tiempo Objetivo |
|-----------|----------------|
| Query BigQuery (scan completo) | < 10 segundos |
| Query BigQuery (partición simple) | < 2 segundos |
| Lectura Firestore (documento único) | < 50 ms |
| Escritura Firestore | < 100 ms |
| Procesamiento Dataflow (por mensaje) | < 100 ms |

---

## 3.3 Restricciones del Sistema

### 3.3.1 Restricciones Técnicas

1. **Plataforma Cloud**: Debe usar Google Cloud Platform
2. **Presupuesto**: Máximo $500/mes para 100 sensores
3. **Lenguajes**: Python para pipelines, C++ para Arduino
4. **Protocolos**: MQTT para IoT, HTTP/REST para APIs
5. **Tiempo de respuesta**: Máximo 20 segundos de latencia E2E

### 3.3.2 Restricciones Operacionales

1. **Hardware**: Sensores DHT11 (precisión ±2°C, ±5% humedad)
2. **Conectividad**: WiFi 2.4GHz requerido
3. **Alimentación**: Sensores con batería o AC
4. **Mantenimiento**: Acceso físico a sensores cada 3-6 meses

### 3.3.3 Restricciones Regulatorias

1. **Privacidad**: Cumplimiento GDPR para datos de ubicación
2. **Retención**: Datos almacenados según regulaciones locales
3. **Auditoría**: Logs de acceso por 2 años

---

[Continúa en la siguiente sección...]
