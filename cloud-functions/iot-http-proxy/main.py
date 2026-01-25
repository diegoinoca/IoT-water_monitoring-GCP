"""
Cloud Function HTTP Proxy para dispositivos IoT Arduino/ESP32
Permite publicar a Pub/Sub usando API Key simple
"""

import functions_framework
from google.cloud import pubsub_v1
import json
import os

# Configuración
PROJECT_ID = os.environ.get('GCP_PROJECT')
TOPIC_ID = os.environ.get('PUBSUB_TOPIC', 'sensor-telemetry')
VALID_API_KEY = os.environ.get('IOT_API_KEY', '')

# Cliente de Pub/Sub
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)


@functions_framework.http
def iot_telemetry(request):
    """Recibe telemetría de dispositivos IoT y publica a Pub/Sub"""
    
    # CORS para requests OPTIONS
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type, X-API-Key',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    headers = {'Access-Control-Allow-Origin': '*'}
    
    # Solo aceptar POST
    if request.method != 'POST':
        return (json.dumps({'error': 'Method not allowed'}), 405, headers)
    
    # Validar API Key (opcional)
    if VALID_API_KEY:
        api_key = request.headers.get('X-API-Key') or request.args.get('api_key')
        if api_key != VALID_API_KEY:
            return (json.dumps({'error': 'Invalid API Key'}), 401, headers)
    
    try:
        # Parsear JSON del Arduino
        data = request.get_json()
        
        # Validar campos requeridos
        required = ['device_id', 'temperature', 'humidity', 'timestamp']
        for field in required:
            if field not in data:
                return (json.dumps({'error': f'Missing field: {field}'}), 400, headers)
        
        # Convertir a bytes para Pub/Sub
        message_bytes = json.dumps(data).encode('utf-8')
        
        # Atributos del mensaje
        attributes = {
            'device_id': str(data['device_id']),
            'location': str(data.get('location', 'unknown')),
            'message_type': 'telemetry'
        }
        
        # Publicar a Pub/Sub (maneja OAuth internamente)
        future = publisher.publish(topic_path, message_bytes, **attributes)
        message_id = future.result(timeout=10)
        
        print(f"[SUCCESS] Published message {message_id} from device {data['device_id']}")
        
        return (json.dumps({
            'success': True,
            'messageId': message_id,
            'deviceId': data['device_id']
        }), 200, headers)
        
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        return (json.dumps({'error': str(e)}), 500, headers)
