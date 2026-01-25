"""
Cloud Function: Procesador de Alertas
Evalúa umbrales de temperatura y humedad y genera alertas cuando se exceden
"""

import os
import json
import base64
import logging
from datetime import datetime
from typing import Dict, Any
from google.cloud import pubsub_v1
from google.cloud import firestore
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Email, To, Content

# Configuración desde variables de entorno
PROJECT_ID = os.environ.get('PROJECT_ID')
ALERT_TOPIC_ID = os.environ.get('ALERT_TOPIC_ID')
TEMPERATURE_THRESHOLD_HIGH = float(os.environ.get('TEMPERATURE_THRESHOLD_HIGH', '30'))
TEMPERATURE_THRESHOLD_LOW = float(os.environ.get('TEMPERATURE_THRESHOLD_LOW', '5'))
HUMIDITY_THRESHOLD_HIGH = float(os.environ.get('HUMIDITY_THRESHOLD_HIGH', '80'))
HUMIDITY_THRESHOLD_LOW = float(os.environ.get('HUMIDITY_THRESHOLD_LOW', '20'))
SENDGRID_API_KEY = os.environ.get('SENDGRID_API_KEY', '')

# Clientes de GCP
publisher = pubsub_v1.PublisherClient()
db = firestore.Client(project=PROJECT_ID)

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def process_alert(event, context):
    """
    Función principal que se ejecuta cuando llega un mensaje de Pub/Sub
    
    Args:
        event: Datos del evento de Pub/Sub
        context: Contexto de la función
    """
    try:
        # Decodificar mensaje de Pub/Sub
        if 'data' in event:
            message_data = base64.b64decode(event['data']).decode('utf-8')
            sensor_reading = json.loads(message_data)
        else:
            logger.error("No data field in event")
            return
        
        logger.info(f"Processing reading from device: {sensor_reading.get('device_id')}")
        
        # Evaluar condiciones de alerta
        alerts = evaluate_thresholds(sensor_reading)
        
        # Procesar alertas si existen
        if alerts:
            for alert in alerts:
                # Guardar alerta en Firestore
                save_alert_to_firestore(alert)
                
                # Publicar alerta a Pub/Sub
                publish_alert(alert)
                
                # Enviar notificación por email
                if SENDGRID_API_KEY:
                    send_email_notification(alert)
                
                logger.info(f"Alert generated: {alert['type']} for device {alert['device_id']}")
        
        return 'OK', 200
        
    except Exception as e:
        logger.error(f"Error processing alert: {e}", exc_info=True)
        return 'Error', 500


def evaluate_thresholds(reading: Dict[str, Any]) -> list:
    """
    Evalúa los umbrales de temperatura y humedad
    
    Args:
        reading: Lectura del sensor
        
    Returns:
        Lista de alertas generadas
    """
    alerts = []
    device_id = reading.get('device_id')
    temperature = reading.get('temperature')
    humidity = reading.get('humidity')
    timestamp = reading.get('timestamp')
    location = reading.get('location', 'unknown')
    
    # Verificar temperatura alta
    if temperature > TEMPERATURE_THRESHOLD_HIGH:
        alerts.append({
            'device_id': device_id,
            'type': 'HIGH_TEMPERATURE',
            'severity': 'WARNING',
            'metric': 'temperature',
            'value': temperature,
            'threshold': TEMPERATURE_THRESHOLD_HIGH,
            'message': f'Temperatura alta detectada: {temperature}°C (umbral: {TEMPERATURE_THRESHOLD_HIGH}°C)',
            'location': location,
            'timestamp': timestamp,
            'created_at': datetime.utcnow().isoformat(),
            'is_active': True,
        })
    
    # Verificar temperatura baja
    if temperature < TEMPERATURE_THRESHOLD_LOW:
        alerts.append({
            'device_id': device_id,
            'type': 'LOW_TEMPERATURE',
            'severity': 'WARNING',
            'metric': 'temperature',
            'value': temperature,
            'threshold': TEMPERATURE_THRESHOLD_LOW,
            'message': f'Temperatura baja detectada: {temperature}°C (umbral: {TEMPERATURE_THRESHOLD_LOW}°C)',
            'location': location,
            'timestamp': timestamp,
            'created_at': datetime.utcnow().isoformat(),
            'is_active': True,
        })
    
    # Verificar humedad alta
    if humidity > HUMIDITY_THRESHOLD_HIGH:
        alerts.append({
            'device_id': device_id,
            'type': 'HIGH_HUMIDITY',
            'severity': 'CRITICAL',
            'metric': 'humidity',
            'value': humidity,
            'threshold': HUMIDITY_THRESHOLD_HIGH,
            'message': f'Humedad alta detectada: {humidity}% (umbral: {HUMIDITY_THRESHOLD_HIGH}%)',
            'location': location,
            'timestamp': timestamp,
            'created_at': datetime.utcnow().isoformat(),
            'is_active': True,
        })
    
    # Verificar humedad baja
    if humidity < HUMIDITY_THRESHOLD_LOW:
        alerts.append({
            'device_id': device_id,
            'type': 'LOW_HUMIDITY',
            'severity': 'CRITICAL',
            'metric': 'humidity',
            'value': humidity,
            'threshold': HUMIDITY_THRESHOLD_LOW,
            'message': f'Humedad baja detectada: {humidity}% (umbral: {HUMIDITY_THRESHOLD_LOW}%)',
            'location': location,
            'timestamp': timestamp,
            'created_at': datetime.utcnow().isoformat(),
            'is_active': True,
        })
    
    return alerts


def save_alert_to_firestore(alert: Dict[str, Any]):
    """
    Guarda la alerta en Firestore
    
    Args:
        alert: Datos de la alerta
    """
    try:
        # Referencia a la colección de alertas
        alerts_ref = db.collection('alerts')
        
        # Generar ID único para la alerta
        alert_id = f"{alert['device_id']}_{alert['type']}_{alert['created_at']}"
        
        # Guardar alerta
        alerts_ref.document(alert_id).set(alert)
        
        # Actualizar contador de alertas del dispositivo
        device_ref = db.collection('devices').document(alert['device_id'])
        device_ref.update({
            'last_alert_timestamp': alert['created_at'],
            'alert_count': firestore.Increment(1),
        })
        
        logger.info(f"Alert saved to Firestore: {alert_id}")
        
    except Exception as e:
        logger.error(f"Error saving alert to Firestore: {e}")


def publish_alert(alert: Dict[str, Any]):
    """
    Publica la alerta en el topic de Pub/Sub
    
    Args:
        alert: Datos de la alerta
    """
    try:
        topic_path = publisher.topic_path(PROJECT_ID, ALERT_TOPIC_ID.split('/')[-1])
        
        # Convertir alerta a JSON
        alert_json = json.dumps(alert).encode('utf-8')
        
        # Publicar mensaje
        future = publisher.publish(topic_path, alert_json)
        future.result()  # Esperar confirmación
        
        logger.info(f"Alert published to Pub/Sub: {alert['type']}")
        
    except Exception as e:
        logger.error(f"Error publishing alert to Pub/Sub: {e}")


def send_email_notification(alert: Dict[str, Any]):
    """
    Envía notificación por email usando SendGrid
    
    Args:
        alert: Datos de la alerta
    """
    try:
        if not SENDGRID_API_KEY or SENDGRID_API_KEY == 'placeholder':
            logger.warning("SendGrid API key not configured, skipping email")
            return
        
        # Construir email
        from_email = Email("alerts@waterquality.com")
        to_email = To("admin@waterquality.com")  # En producción, esto vendría de configuración
        subject = f"ALERTA: Calidad de Agua - {alert['type']}"
        
        # Contenido HTML del email
        html_content = f"""
        <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
                <h2 style="color: {'#d32f2f' if alert['severity'] == 'CRITICAL' else '#f57c00'};">
                    Alerta de {alert['severity']}
                </h2>
                <p><strong>Dispositivo:</strong> {alert['device_id']}</p>
                <p><strong>Ubicación:</strong> {alert['location']}</p>
                <p><strong>Tipo de Alerta:</strong> {alert['type']}</p>
                <p><strong>Mensaje:</strong> {alert['message']}</p>
                <p><strong>Valor Detectado:</strong> {alert['value']}</p>
                <p><strong>Umbral:</strong> {alert['threshold']}</p>
                <p><strong>Timestamp:</strong> {alert['timestamp']}</p>
                <hr>
                <p style="font-size: 12px; color: #666;">
                    Esta es una alerta automática del Sistema de Monitoreo de Calidad de Agua.
                </p>
            </body>
        </html>
        """
        
        content = Content("text/html", html_content)
        mail = Mail(from_email, to_email, subject, content)
        
        # Enviar email
        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(mail)
        
        logger.info(f"Email notification sent: {response.status_code}")
        
    except Exception as e:
        logger.error(f"Error sending email notification: {e}")


if __name__ == '__main__':
    # Para testing local
    test_event = {
        'data': base64.b64encode(json.dumps({
            'device_id': 'test-sensor-001',
            'timestamp': datetime.utcnow().isoformat(),
            'temperature': 35.5,
            'humidity': 85.0,
            'location': 'Rio Principal',
        }).encode('utf-8'))
    }
    
    process_alert(test_event, None)
