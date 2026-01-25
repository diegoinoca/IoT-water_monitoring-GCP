# Diagramas de Arquitectura - Sistema IoT de Monitoreo de Calidad de Aguas

**ACTUALIZADO 2026**: Arquitectura sin Cloud IoT Core (deprecado), usando Cloud Function HTTP Proxy.

## 1. Diagrama de Arquitectura de Alto Nivel (ACTUALIZADO)

```mermaid
graph TB
    subgraph "Capa de Dispositivos IoT"
        A1[Arduino + DHT11]
        A2[Arduino + DHT11]
        A3[Arduino + DHT11]
        A4[ESP32 WiFi Module]
    end
    
    subgraph "Google Cloud Platform"
        subgraph "Capa de Ingesta"
            B1[Cloud Function<br/>HTTP Proxy]
            B2[API Key<br/>Authentication]
            B3[Cloud Pub/Sub<br/>Telemetry Topic]
        end
        
        subgraph "Capa de Procesamiento"
            C1[Cloud Dataflow<br/>Stream Processing]
            C2[Cloud Functions<br/>Alert Processor]
            C3[Cloud Functions<br/>Realtime Updater]
        end
        
        subgraph "Capa de Almacenamiento"
            D1[(BigQuery<br/>Raw Readings)]
            D2[(BigQuery<br/>Aggregations)]
            D3[Cloud Storage<br/>Backup]
            D4[(Firestore<br/>Real-time DB)]
        end
        
        subgraph "Capa de Notificaciones"
            E1[Pub/Sub<br/>Alerts Topic]
            E2[SendGrid<br/>Email]
            E3[SMS/Push<br/>Notifications]
        end
        
        subgraph "Capa de Visualización"
            F1[Looker Studio<br/>Dashboards]
            F2[Web Dashboard<br/>Real-time]
            F3[Mobile App]
        end
    end
    
    A1 & A2 & A3 -->|WiFi| A4
    A4 -->|HTTPS POST<br/>JSON + API Key| B1
    B2 -.->|Valida| B1
    B1 -->|OAuth2 interno| B3
    
    B3 -->|Subscribe| C1
    B3 -->|Subscribe| C2
    B3 -->|Subscribe| C3
    
    C1 --> D1 & D2 & D3
    C2 --> E1 & D4
    C3 --> D4
    
    E1 --> E2 & E3
    
    D1 & D2 --> F1
    D4 --> F2 & F3
    
```

## 2. Diagrama de Flujo de Datos

```mermaid
sequenceDiagram
    participant Arduino as Arduino + DHT11
    participant ESP32 as ESP32 WiFi
    participant Proxy as Cloud Function<br/>HTTP Proxy
    participant PubSub as Cloud Pub/Sub
    participant Dataflow as Cloud Dataflow
    participant BQ as BigQuery
    participant CS as Cloud Storage
    participant CF as Cloud Functions
    participant FS as Firestore
    participant Email as SendGrid
    
    Note over Arduino: Cada 30 segundos
    Arduino->>Arduino: Leer temperatura y humedad
    Arduino->>ESP32: Enviar datos
    ESP32->>Proxy: HTTPS POST<br/>{temp, humidity, timestamp}<br/>Header: X-API-Key
    Proxy->>Proxy: Validar API Key
    Proxy->>PubSub: Publicar en Topic<br/>(con OAuth2 interno)
    
    par Procesamiento Paralelo
        PubSub->>Dataflow: Stream de datos
        Dataflow->>Dataflow: Validar y transformar
        Dataflow->>Dataflow: Calcular agregaciones<br/>(ventanas de 1 min)
        Dataflow->>BQ: Escribir datos raw
        Dataflow->>BQ: Escribir agregaciones
        Dataflow->>CS: Backup en formato JSON
    and
        PubSub->>CF: Trigger Alert Processor
        CF->>CF: Evaluar umbrales
        alt Umbral excedido
            CF->>PubSub: Publicar alerta
            CF->>FS: Guardar alerta
            CF->>Email: Enviar notificación
        end
    and
        PubSub->>CF: Trigger Realtime Updater
        CF->>FS: Actualizar última lectura
        CF->>FS: Actualizar estadísticas
    end
    
    Note over BQ,FS: Datos disponibles para consulta
```

## 3. Diagrama de Componentes Detallado

```mermaid
graph LR
    subgraph "Edge Layer"
        S1[DHT11 Sensor]
        S2[Arduino UNO]
        S3[ESP32 WiFi]
    end
    
    subgraph "HTTP Proxy Layer"
        P0[Cloud Function<br/>iot-http-proxy]
        P01[API Key Validation]
        P02[JSON Parser]
        P03[Pub/Sub Publisher]
    end
    
    subgraph "Pub/Sub Topics"
        P1[sensor-telemetry]
        P2[sensor-alerts]
        P3[dead-letter-queue]
    end
    
    subgraph "Stream Processing"
        DF1[Dataflow Job]
        DF2[Parse Messages]
        DF3[Validate Data]
        DF4[Window Aggregations]
        DF5[Write to Sinks]
    end
    
    subgraph "Storage Layer"
        BQ1[BigQuery Dataset]
        BQ2[Table: raw_readings]
        BQ3[Table: aggregations_minute]
        BQ4[Table: aggregations_hour]
        BQ5[View: latest_readings]
        BQ6[View: hourly_statistics]
        CS1[GCS Bucket: raw-data]
        FS1[Firestore: devices]
        FS2[Firestore: current_readings]
        FS3[Firestore: alerts]
    end
    
    subgraph "Serverless Functions"
        CF1[Alert Processor]
        CF2[Realtime Updater]
        CF3[Threshold Evaluator]
    end
    
    S1 --> S2 --> S3
    S3 -->|HTTPS POST<br/>X-API-Key| P0
    P0 --> P01 --> P02 --> P03
    P03 --> P1
    
    P1 --> DF1
    DF1 --> DF2 --> DF3 --> DF4 --> DF5
    
    DF5 --> BQ2 & BQ3 & BQ4 & CS1
    
    P1 --> CF1 & CF2
    CF1 --> CF3 --> P2
    CF1 --> FS3
    CF2 --> FS1 & FS2
    
    BQ2 -.->|Depends on| BQ1
    BQ3 -.-> BQ1
    BQ4 -.-> BQ1
    BQ5 -.->|Depends on| BQ2
    BQ6 -.->|Depends on| BQ2
```

## 4. Diagrama de Despliegue

```mermaid
graph TB
    subgraph "On-Premises / Field"
        subgraph "Ubicación 1: Rio Principal"
            D1[Sensor-001<br/>Arduino+ESP32]
            D2[Sensor-002<br/>Arduino+ESP32]
        end
        
        subgraph "Ubicación 2: Lago Norte"
            D3[Sensor-003<br/>Arduino+ESP32]
            D4[Sensor-004<br/>Arduino+ESP32]
        end
        
        subgraph "Ubicación 3: Reserva Sur"
            D5[Sensor-005<br/>Arduino+ESP32]
        end
    end
    
    subgraph "Google Cloud Platform - us-central1"
        subgraph "Compute"
            C0[Cloud Function<br/>iot-http-proxy<br/>256MB RAM]
            C1[Dataflow Workers<br/>n1-standard-2<br/>Auto-scaling: 1-5]
            C2[Cloud Functions<br/>alert-processor<br/>realtime-updater<br/>Gen 2, 256MB RAM]
        end
        
        subgraph "Storage"
            S1[BigQuery<br/>Partitioned Tables<br/>Clustered by device_id]
            S2[Cloud Storage<br/>Standard Class<br/>Backup Data]
            S3[Firestore<br/>Native Mode<br/>us-central]
        end
        
        subgraph "Messaging"
            N1[Cloud Function<br/>HTTP Proxy<br/>API Key Auth]
            N2[Pub/Sub<br/>sensor-telemetry<br/>sensor-alerts]
        end
        
        subgraph "Monitoring"
            M1[Cloud Logging]
            M2[Cloud Monitoring]
            M3[Cloud Trace]
        end
    end
    
    D1 & D2 & D3 & D4 & D5 -->|HTTPS POST<br/>WiFi/Internet| C0
    C0 -->|OAuth2| N2
    N2 --> C1 & C2
    C1 --> S1 & S2
    C2 --> S3
    
    C0 & C1 & C2 --> M1 & M2 & M3
    
```

## 5. Diagrama de Procesos de Alertas

```mermaid
flowchart TD
    Start([Nueva Lectura<br/>del Sensor]) --> Parse[Parsear Mensaje JSON]
    Parse --> CheckTemp{Temperatura<br/>fuera de rango?}
    
    CheckTemp -->|Sí| TempAlert[Generar Alerta<br/>de Temperatura]
    CheckTemp -->|No| CheckHum{Humedad<br/>fuera de rango?}
    
    CheckHum -->|Sí| HumAlert[Generar Alerta<br/>de Humedad]
    CheckHum -->|No| NoAlert[No hay alertas]
    
    TempAlert --> Severity{Determinar<br/>Severidad}
    HumAlert --> Severity
    
    Severity -->|CRITICAL| Critical[Severity: CRITICAL]
    Severity -->|WARNING| Warning[Severity: WARNING]
    
    Critical --> SaveFS[Guardar en Firestore]
    Warning --> SaveFS
    
    SaveFS --> PubTopic[Publicar en<br/>Alerts Topic]
    PubTopic --> SendEmail{SendGrid<br/>configurado?}
    
    SendEmail -->|Sí| Email[Enviar Email]
    SendEmail -->|No| Skip[Saltar Email]
    
    Email --> UpdateDevice[Actualizar contador<br/>de alertas del device]
    Skip --> UpdateDevice
    NoAlert --> End([Fin])
    UpdateDevice --> End
    

```

## 6. Diagrama de Modelo de Datos

```mermaid
erDiagram
    DEVICES ||--o{ CURRENT_READINGS : has
    DEVICES ||--o{ ALERTS : generates
    DEVICES ||--o{ DEVICE_STATISTICS : tracks
    
    DEVICES {
        string device_id PK
        string location
        float latitude
        float longitude
        timestamp first_seen
        timestamp last_seen
        string status
        int total_readings
        timestamp created_at
    }
    
    CURRENT_READINGS {
        string device_id PK
        timestamp timestamp
        float temperature
        float humidity
        float water_quality_index
        string location
        timestamp last_updated
    }
    
    RAW_READINGS {
        string device_id
        timestamp timestamp
        float temperature
        float humidity
        string location
        float latitude
        float longitude
        float water_quality_index
        json metadata
        timestamp ingestion_timestamp
    }
    
    AGGREGATIONS_MINUTE {
        string device_id
        timestamp window_start
        timestamp window_end
        string location
        float avg_temperature
        float min_temperature
        float max_temperature
        float avg_humidity
        float min_humidity
        float max_humidity
        int reading_count
        timestamp processing_timestamp
    }
    
    ALERTS {
        string alert_id PK
        string device_id FK
        string type
        string severity
        string metric
        float value
        float threshold
        string message
        timestamp created_at
        boolean is_active
    }
    
    DEVICE_STATISTICS {
        string device_id PK
        float temperature_avg
        float temperature_min
        float temperature_max
        float humidity_avg
        float humidity_min
        float humidity_max
        int reading_count
        timestamp last_updated
    }
```

## 7. Diagrama de Red y Seguridad

```mermaid
graph TB
    subgraph "Internet"
        IoT[Dispositivos IoT]
        Users[Usuarios Web/Mobile]
    end
    
    subgraph "GCP Security Perimeter"
        subgraph "IAM & Authentication"
            IAM1[Service Accounts]
            IAM2[API Key Validation<br/>HTTP Proxy]
            IAM3[OAuth2 Internal<br/>Pub/Sub Access]
        end
        
        subgraph "Network Security"
            FW[Cloud Armor<br/>DDoS Protection]
            LB[Cloud Load Balancer<br/>SSL/TLS Termination]
            VPC[VPC Network<br/>Private IPs]
        end
        
        subgraph "Data Encryption"
            E1[Encryption at Rest<br/>Google-managed keys]
            E2[Encryption in Transit<br/>TLS 1.2+]
        end
        
        subgraph "Services"
            SVC0[Cloud Function<br/>HTTP Proxy]
            SVC2[Pub/Sub]
            SVC3[Dataflow]
            SVC4[BigQuery]
            SVC5[Firestore]
        end
    end
    
    IoT -->|HTTPS + API Key| IAM2
    IAM2 --> SVC0
    SVC0 --> IAM3
    IAM3 --> SVC2
    
    Users -->|HTTPS| FW
    FW --> LB
    LB --> VPC
    
    SVC0 --> E2
    SVC2 --> E2
    SVC3 --> E2
    SVC4 --> E1 & E2
    SVC5 --> E1 & E2
    
    IAM1 -.->|Authorize| SVC3 & SVC4 & SVC5
    
    style IAM2 fill:#FF9800
    style E1 fill:#4CAF50
    style E2 fill:#4CAF50
    style FW fill:#F44336
    style SVC0 fill:#EA4335
```

## 8. Diagrama de Escalabilidad y Auto-scaling

```mermaid
graph LR
    subgrapHTTP Requests<br/>to Proxy]
    end
    
    subgraph "Auto-scaling Policies"
        P1[Dataflow<br/>Min: 1 worker<br/>Max: 5 workers]
        P2[Cloud Functions<br/>HTTP Proxy<br/>Max: 10 instances]
        P3[Cloud Functions<br/>Processors<br/>Max: 100 instances]
    end
    
    subgraph "Scaled Resources"
        R1[Dataflow Worker 1]
        R2[Dataflow Worker 2]
        R3[Dataflow Worker N]
        R4[Proxy Instance 1]
        R5[Proxy Instance N]
        R6[Function Instance 1]
        R7[Function Instance N]
    end
    
    M1 --> P1
    M2 --> P1
    M3 --> P2
    
    P1 -.->|Scale Up/Down| R1 & R2 & R3
    P2 -.->|Scale Up/Down| R4 & R5
    P3 -.->|Scale Up/Down| R6 & R7
    
    P1 -.->|Scale Up/Down| R1 & R2 & R3
    P2 -.->|Scale Up/Down| R4 & R5
    
```
