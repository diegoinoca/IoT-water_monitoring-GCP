/*
 * Sistema IoT de Monitoreo de Calidad de Aguas
 * Versión HTTP con Pub/Sub directo (sin Cloud IoT Core)
 * 
 * Hardware requerido:
 * - ESP32
 * - Sensor DHT11
 * 
 * Conexiones:
 * DHT11 VCC  -> ESP32 3.3V
 * DHT11 GND  -> ESP32 GND
 * DHT11 DATA -> ESP32 GPIO 4
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <time.h>

// ============================================================================
// CONFIGURACIÓN DEL SENSOR DHT11
// ============================================================================
#define DHTPIN 17
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// ============================================================================
// CONFIGURACIÓN WiFi
// ============================================================================
const char* WIFI_SSID = "TU_WIFI_SSID";
const char* WIFI_PASSWORD = "TU_WIFI_PASSWORD";

// ============================================================================
// CONFIGURACIÓN GOOGLE CLOUD
// ============================================================================
const char* PROJECT_ID = PROJECT_ID
const char* API_KEY = API_KEY 

// URL del proxy HTTP (Cloud Function)
// Obtener de: terraform output -raw iot_http_proxy_url
String PROXY_URL = PROXY_URL

// ============================================================================
// CONFIGURACIÓN DEL DISPOSITIVO
// ============================================================================
const char* DEVICE_ID = "sensor-001";
const char* DEVICE_LOCATION = "Rio Principal, Santiago";
const float DEVICE_LATITUDE = -33.4489;
const float DEVICE_LONGITUDE = -70.6693;

// ============================================================================
// CONFIGURACIÓN DEL SISTEMA
// ============================================================================
const unsigned long READING_INTERVAL = 30000;  // 30 segundos
unsigned long lastReadingTime = 0;
unsigned long messageCount = 0;

// NTP Server para timestamp
const char* NTP_SERVER = "pool.ntp.org";
const long GMT_OFFSET_SEC = -10800;  // GMT-3 (Chile)
const int DAYLIGHT_OFFSET_SEC = 0;

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println();
  Serial.println("========================================");
  Serial.println("Sistema IoT de Monitoreo de Calidad de Aguas");
  Serial.println("Version: HTTP/Pub/Sub Direct");
  Serial.println("========================================");
  
  // Inicializar sensor DHT11
  dht.begin();
  Serial.println("Sensor DHT11 inicializado");
  
  // Conectar a WiFi
  connectWiFi();
  
  // Sincronizar reloj con NTP
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER);
  Serial.print("Sincronizando tiempo NTP...");
  
  struct tm timeinfo;
  if(!getLocalTime(&timeinfo)){
    Serial.println(" ERROR");
  } else {
    Serial.println(" OK");
  }
  
  Serial.println("Sistema inicializado correctamente");
  Serial.println("========================================");
  
  printDeviceInfo();
}

// ============================================================================
// LOOP PRINCIPAL
// ============================================================================
void loop() {
  // Verificar conexión WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi desconectado. Reconectando...");
    connectWiFi();
  }
  
  // Leer y enviar datos según intervalo configurado
  if (millis() - lastReadingTime >= READING_INTERVAL) {
    readAndSendData();
    lastReadingTime = millis();
  }
  
  delay(100);
}

// ============================================================================
// FUNCIONES DE CONECTIVIDAD
// ============================================================================

void connectWiFi() {
  Serial.print("Conectando a WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi conectado");
    Serial.print("  IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("  RSSI: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\nError: No se pudo conectar a WiFi");
  }
}

// ============================================================================
// FUNCIONES DE LECTURA Y ENVÍO DE DATOS
// ============================================================================

void readAndSendData() {
  Serial.println("----------------------------------------");
  Serial.println("Leyendo sensores...");
  
  // Leer temperatura y humedad del DHT11
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  
  // Verificar si la lectura fue exitosa
  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Error: Fallo al leer del sensor DHT11");
    return;
  }
  
  // Mostrar lecturas
  Serial.print("  Temperatura: ");
  Serial.print(temperature);
  Serial.println(" °C");
  
  Serial.print("  Humedad: ");
  Serial.print(humidity);
  Serial.println(" %");
  
  // Crear y enviar payload
  if (publishToPubSub(temperature, humidity)) {
    messageCount++;
    Serial.println("Datos enviados exitosamente a Pub/Sub");
    Serial.print("  Total mensajes enviados: ");
    Serial.println(messageCount);
  } else {
    Serial.println("Error al enviar datos");
  }
  
  Serial.println("----------------------------------------");
}

bool publishToPubSub(float temperature, float humidity) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("  Error: WiFi no conectado");
    return false;
  }

  HTTPClient http;
  http.begin(PROXY_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", API_KEY);
  http.setTimeout(10000);  // 10 segundos timeout
  
  // Crear mensaje JSON para el proxy HTTP
  StaticJsonDocument<512> dataDoc;
  dataDoc["device_id"] = DEVICE_ID;
  dataDoc["timestamp"] = getISOTimestamp();
  dataDoc["temperature"] = round(temperature * 100.0) / 100.0;  // 2 decimales
  dataDoc["humidity"] = round(humidity * 100.0) / 100.0;
  dataDoc["location"] = DEVICE_LOCATION;
  dataDoc["latitude"] = DEVICE_LATITUDE;
  dataDoc["longitude"] = DEVICE_LONGITUDE;
  dataDoc["message_count"] = messageCount + 1;
  dataDoc["rssi"] = WiFi.RSSI();

  String jsonPayload;
  serializeJson(dataDoc, jsonPayload);

  Serial.println("  JSON generado:");
  Serial.print("  ");
  Serial.println(jsonPayload);

  // Enviar HTTP POST (el proxy maneja la publicación a Pub/Sub)
  Serial.println("  Enviando al proxy HTTP...");
  int httpCode = http.POST(jsonPayload);
  
  bool success = false;
  if (httpCode == 200) {
    Serial.print("  Respuesta HTTP: ");
    Serial.println(httpCode);
    
    String response = http.getString();
    Serial.print("  Respuesta: ");
    Serial.println(response);
    
    Serial.println("  Mensaje publicado exitosamente");
    success = true;
  } else {
    Serial.print("  Error HTTP: ");
    Serial.println(httpCode);
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.print("  Respuesta: ");
      Serial.println(response);
    } else {
      Serial.println("  Error de conexión");
    }
  }
  
  http.end();
  return success;
}

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

String getISOTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    // Si falla NTP, usar millis()
    return String(millis());
  }
  
  char timestamp[30];
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(timestamp);
}

void printDeviceInfo() {
  Serial.println("\n========================================");
  Serial.println("Información del Dispositivo");
  Serial.println("========================================");
  Serial.print("Device ID: ");
  Serial.println(DEVICE_ID);
  Serial.print("Ubicación: ");
  Serial.println(DEVICE_LOCATION);
  Serial.print("Coordenadas: ");
  Serial.print(DEVICE_LATITUDE, 4);
  Serial.print(", ");
  Serial.println(DEVICE_LONGITUDE, 4);
  Serial.print("Intervalo de lectura: ");
  Serial.print(READING_INTERVAL / 1000);
  Serial.println(" segundos");
  Serial.print("URL Proxy HTTP: ");
  Serial.println(PROXY_URL);
  Serial.println("========================================\n");
}
