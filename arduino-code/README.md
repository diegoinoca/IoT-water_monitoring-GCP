# Código Arduino para Sensores IoT (HTTP/Pub/Sub Directo)

**ACTUALIZADO 2024**: Este código ya NO requiere Cloud IoT Core (deprecado).
Ahora usa HTTP POST directo a Cloud Pub/Sub con API Key.

## Hardware Requerido

### Componentes Principales
- **ESP32 DevKit** (recomendado por WiFi integrado)
- **Sensor DHT11** (temperatura y humedad)
- **Cables jumper** (macho-hembra)
- **Protoboard** (opcional, para prototipado)
- **Cable micro-USB** (para programación y alimentación)

### Componentes Opcionales
- GPS Module (NEO-6M) para coordenadas precisas
- Sensor de pH
- Sensor de oxígeno disuelto
- Batería LiPo + módulo de carga (para operación autónoma)
- Carcasa impermeable (para instalación exterior)

## Diagrama de Conexiones

### ESP32 + DHT11

```
ESP32                DHT11
-----                -----
3.3V    ---------->  VCC
GND     ---------->  GND
GPIO4   ---------->  DATA
```

### Notas de Conexión
- **VCC**: 3.3V (NO usar 5V con ESP32)
- **DATA**: Incluir resistor pull-up de 10kΩ entre DATA y VCC
- El pin DATA puede conectarse a cualquier GPIO digital (código usa GPIO4 por defecto)

## Librerías Necesarias

Instalar desde el Library Manager de Arduino IDE:

1. **DHT sensor library** by Adafruit
2. **Adafruit Unified Sensor** (dependencia de DHT)
3. **ArduinoJson** by Benoit Blanchon (v6.x o superior)
4. **Base64** by Arturo Guadalupi

```bash
# Desde Arduino IDE:
Sketch > Include Library > Manage Libraries > Buscar cada librería
```

## Configuración

### 1. Obtener API Key de Terraform

Después de desplegar la infraestructura con Terraform:

```bash
cd terraform
terraform output -raw api_key_iot_devices
```

**IMPORTANTE**: Guardar esta API Key de forma segura. NO compartir públicamente ni subir a Git.

### 2. Configurar el Código

Editar `sensor_http/sensor_http.ino` y modificar estas constantes:

```cpp
// WiFi
const char* WIFI_SSID = "TU_WIFI_SSID";
const char* WIFI_PASSWORD = "TU_WIFI_PASSWORD";

// Google Cloud
const char* PROJECT_ID = "tu-proyecto-gcp";
const char* TOPIC_NAME = "sensor-telemetry";
const char* API_KEY = "TU_API_KEY_AQUI";  // De terraform output

// Dispositivo
const char* DEVICE_ID = "sensor-001";
const char* DEVICE_LOCATION = "Rio Principal, Santiago";
const float DEVICE_LATITUDE = -33.4489;
const float DEVICE_LONGITUDE = -70.6693;
```

### 3. Configurar Arduino IDE para ESP32

1. Abrir Arduino IDE
2. Ir a **File > Preferences**
3. En "Additional Boards Manager URLs", añadir:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Ir a **Tools > Board > Boards Manager**
5. Buscar "esp32" e instalar "esp32 by Espressif Systems"

### 4. Cargar el Código

1. Abrir `sensor_http/sensor_http.ino` en Arduino IDE
2. Seleccionar placa: **Tools > Board > ESP32 Arduino > ESP32 Dev Module**
3. Seleccionar puerto: **Tools > Port > COMx** (Windows) o `/dev/ttyUSB0` (Linux)
4. Compilar: Click en **Verify** (✓)
5. Cargar: Click en **Upload** (→)

## Monitoreo y Debug

### Monitor Serial

1. Abrir: **Tools > Serial Monitor**
2. Configurar baudrate: **115200**
3. Observar logs

### Logs Esperados (Exitoso)

```
========================================
Sistema IoT de Monitoreo de Calidad de Aguas
Version: HTTP/Pub/Sub Direct
========================================
Sensor DHT11 inicializado
Conectando a WiFi: MI_WIFI
..
WiFi conectado
  IP: 192.168.1.100
  RSSI: -45 dBm
Sincronizando tiempo NTP... OK
Sistema inicializado correctamente
========================================

========================================
Información del Dispositivo
========================================
Device ID: sensor-001
Ubicación: Rio Principal, Santiago
Coordenadas: -33.4489, -70.6693
Intervalo de lectura: 30 segundos
URL Pub/Sub: https://pubsub.googleapis.com/v1/projects/...
========================================

----------------------------------------
Leyendo sensores...
  Temperatura: 25.5 °C
  Humedad: 65.0 %
  JSON generado:
  {"device_id":"sensor-001","timestamp":"2024-01-18T12:30:00Z",...}
  Enviando a Pub/Sub...
  Respuesta HTTP: 200
  Respuesta: {"messageIds":["1234567890"]}
  Mensaje publicado exitosamente
Datos enviados exitosamente a Pub/Sub
  Total mensajes enviados: 1
----------------------------------------
```

## Troubleshooting

### Error: No se pudo conectar a WiFi

**Síntomas**: Se queda en "Connecting to WiFi..."

**Soluciones**:
- Verificar SSID y contraseña correctos
- Verificar que la red es 2.4GHz (ESP32 NO soporta 5GHz)
- Acercar ESP32 al router
- Verificar que la red WiFi está funcionando

### Error HTTP 401 (Unauthorized)

**Síntomas**: `Error HTTP: 401`

**Causa**: API Key inválida o expirada

**Solución**:
```bash
# Regenerar API Key
cd terraform
terraform apply
terraform output -raw api_key_iot_devices
# Actualizar en sensor_http.ino
```

### Error HTTP 403 (Permission Denied)

**Síntomas**: `Error HTTP: 403`

**Causa**: API Key no tiene permisos para publicar en Pub/Sub

**Solución**: Verificar restricciones de API Key en `terraform/main.tf`

### Error HTTP 404 (Not Found)

**Síntomas**: `Error HTTP: 404`

**Causa**: Topic de Pub/Sub no existe o nombre incorrecto

**Solución**:
```bash
# Verificar topics existentes
gcloud pubsub topics list --project=TU_PROYECTO

# Verificar nombre en código coincide con Terraform
```

### Error de Compilación: Librerías Faltantes

**Síntomas**: `fatal error: DHT.h: No such file or directory`

**Solución**: Instalar librerías faltantes (ver sección "Librerías Necesarias")

### Fallo al Leer Sensor DHT11

**Síntomas**: `Error: Fallo al leer del sensor DHT11`

**Soluciones**:
- Verificar conexiones físicas (VCC, GND, DATA)
- Asegurar resistor pull-up de 10kΩ entre DATA y VCC
- Reemplazar sensor (DHT11 puede fallar)
- Probar con GPIO diferente
- Aumentar delay entre lecturas

## Verificación de Datos en GCP

### Verificar Mensajes en Pub/Sub

```bash
# Consumir mensajes de la subscription
gcloud pubsub subscriptions pull sensor-telemetry-dataflow-sub \
  --project=TU_PROYECTO \
  --limit=10 \
  --auto-ack
```

### Verificar Datos en BigQuery

```bash
# Query directa
bq query --use_legacy_sql=false \
  'SELECT * FROM `proyecto.sensor_data.raw_readings` 
   WHERE device_id = "sensor-001" 
   ORDER BY timestamp DESC 
   LIMIT 10'
```

## Ventajas vs Cloud IoT Core (Deprecado)

| Aspecto | Cloud IoT Core (Viejo) | HTTP/Pub/Sub (Nuevo) |
|---------|------------------------|----------------------|
| **Autenticación** | Certificados RSA + JWT | API Key simple |
| **Protocolo** | MQTT | HTTP REST |
| **Complejidad** | Alta | Baja |
| **Código Arduino** | ~500 líneas | ~300 líneas |
| **Debugging** | Difícil (MQTT) | Fácil (HTTP) |
| **Latencia** | ~150ms | ~100ms |
| **Costo mensual** | $5 | $0.35 |
| **Mantenimiento** | Deprecado | Soportado |

## Optimización de Energía

Para operación con batería (opcional):

```cpp
#include <esp_sleep.h>

void enterDeepSleep() {
  // ESP32 dormirá y despertará en READING_INTERVAL
  esp_sleep_enable_timer_wakeup(READING_INTERVAL * 1000);
  esp_deep_sleep_start();
}

void loop() {
  readAndSendData();
  enterDeepSleep(); // Dormir entre lecturas
}
```

**Ahorro de energía**: ~99% (de 240mA a 10µA en deep sleep)

## Siguientes Pasos

1. Configurar y probar primer dispositivo
2. Verificar datos llegando a BigQuery
3. Escalar a múltiples dispositivos (cambiar DEVICE_ID)
4. Implementar carcasa impermeable para exterior
5. Configurar batería + panel solar (opcional)
6. Añadir sensores adicionales (pH, oxígeno disuelto)

## Soporte

- **Documentación ESP32**: https://docs.espressif.com/
- **Forum Arduino**: https://forum.arduino.cc/
- **Cloud Pub/Sub Docs**: https://cloud.google.com/pubsub/docs
- **Troubleshooting GCP**: [docs/troubleshooting.md](../docs/troubleshooting.md)
