"""
Cloud Function: Actualizador en Tiempo Real
Actualiza Firestore con las últimas lecturas de cada dispositivo
"""

import os
import json
import base64
import logging
from datetime import datetime
from typing import Dict, Any
from google.cloud import firestore

# Configuración
PROJECT_ID = os.environ.get('PROJECT_ID')

# Cliente de Firestore
db = firestore.Client(project=PROJECT_ID)

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def update_firestore(event, context):
    """
    Función principal que actualiza Firestore con las últimas lecturas
    
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
        
        device_id = sensor_reading.get('device_id')
        logger.info(f"Updating Firestore for device: {device_id}")
        
        # Actualizar información del dispositivo
        update_device_info(sensor_reading)
        
        # Actualizar lectura actual
        update_current_reading(sensor_reading)
        
        # Actualizar estadísticas del dispositivo
        update_device_statistics(sensor_reading)
        
        return 'OK', 200
        
    except Exception as e:
        logger.error(f"Error updating Firestore: {e}", exc_info=True)
        return 'Error', 500


def update_device_info(reading: Dict[str, Any]):
    """
    Actualiza o crea el documento del dispositivo en Firestore
    
    Args:
        reading: Lectura del sensor
    """
    try:
        device_id = reading.get('device_id')
        device_ref = db.collection('devices').document(device_id)
        
        # Verificar si el dispositivo existe
        device_doc = device_ref.get()
        
        if not device_doc.exists:
            # Crear nuevo dispositivo
            device_data = {
                'device_id': device_id,
                'location': reading.get('location', 'unknown'),
                'latitude': reading.get('latitude'),
                'longitude': reading.get('longitude'),
                'first_seen': datetime.utcnow().isoformat(),
                'last_seen': datetime.utcnow().isoformat(),
                'status': 'online',
                'total_readings': 1,
                'created_at': datetime.utcnow().isoformat(),
            }
            device_ref.set(device_data)
            logger.info(f"New device created: {device_id}")
        else:
            # Actualizar dispositivo existente
            device_ref.update({
                'last_seen': datetime.utcnow().isoformat(),
                'status': 'online',
                'total_readings': firestore.Increment(1),
            })
            
            # Actualizar ubicación si cambió
            if 'location' in reading:
                device_ref.update({'location': reading['location']})
            if 'latitude' in reading and 'longitude' in reading:
                device_ref.update({
                    'latitude': reading['latitude'],
                    'longitude': reading['longitude'],
                })
        
    except Exception as e:
        logger.error(f"Error updating device info: {e}")


def update_current_reading(reading: Dict[str, Any]):
    """
    Actualiza la lectura actual del dispositivo
    
    Args:
        reading: Lectura del sensor
    """
    try:
        device_id = reading.get('device_id')
        
        # Referencia a la colección de lecturas actuales
        current_reading_ref = db.collection('current_readings').document(device_id)
        
        # Preparar datos de la lectura
        reading_data = {
            'device_id': device_id,
            'timestamp': reading.get('timestamp'),
            'temperature': reading.get('temperature'),
            'humidity': reading.get('humidity'),
            'location': reading.get('location', 'unknown'),
            'latitude': reading.get('latitude'),
            'longitude': reading.get('longitude'),
            'water_quality_index': reading.get('water_quality_index'),
            'last_updated': datetime.utcnow().isoformat(),
        }
        
        # Actualizar o crear documento
        current_reading_ref.set(reading_data, merge=True)
        
        logger.info(f"Current reading updated for device: {device_id}")
        
    except Exception as e:
        logger.error(f"Error updating current reading: {e}")


def update_device_statistics(reading: Dict[str, Any]):
    """
    Actualiza las estadísticas del dispositivo (promedios, min, max)
    
    Args:
        reading: Lectura del sensor
    """
    try:
        device_id = reading.get('device_id')
        temperature = reading.get('temperature')
        humidity = reading.get('humidity')
        
        # Referencia a estadísticas del dispositivo
        stats_ref = db.collection('device_statistics').document(device_id)
        stats_doc = stats_ref.get()
        
        if not stats_doc.exists:
            # Crear estadísticas iniciales
            stats_data = {
                'device_id': device_id,
                'temperature_sum': temperature,
                'temperature_min': temperature,
                'temperature_max': temperature,
                'temperature_avg': temperature,
                'humidity_sum': humidity,
                'humidity_min': humidity,
                'humidity_max': humidity,
                'humidity_avg': humidity,
                'reading_count': 1,
                'last_updated': datetime.utcnow().isoformat(),
            }
            stats_ref.set(stats_data)
        else:
            # Actualizar estadísticas existentes
            stats = stats_doc.to_dict()
            
            new_count = stats['reading_count'] + 1
            new_temp_sum = stats['temperature_sum'] + temperature
            new_humidity_sum = stats['humidity_sum'] + humidity
            
            stats_ref.update({
                'temperature_sum': new_temp_sum,
                'temperature_min': min(stats['temperature_min'], temperature),
                'temperature_max': max(stats['temperature_max'], temperature),
                'temperature_avg': new_temp_sum / new_count,
                'humidity_sum': new_humidity_sum,
                'humidity_min': min(stats['humidity_min'], humidity),
                'humidity_max': max(stats['humidity_max'], humidity),
                'humidity_avg': new_humidity_sum / new_count,
                'reading_count': new_count,
                'last_updated': datetime.utcnow().isoformat(),
            })
        
        logger.info(f"Statistics updated for device: {device_id}")
        
    except Exception as e:
        logger.error(f"Error updating device statistics: {e}")


def check_device_connectivity():
    """
    Función auxiliar para verificar la conectividad de dispositivos
    Puede ser llamada por un Cloud Scheduler periódicamente
    """
    try:
        # Obtener todos los dispositivos
        devices = db.collection('devices').stream()
        
        now = datetime.utcnow()
        offline_threshold_minutes = 5
        
        for device in devices:
            device_data = device.to_dict()
            last_seen_str = device_data.get('last_seen')
            
            if last_seen_str:
                last_seen = datetime.fromisoformat(last_seen_str)
                minutes_since_last_seen = (now - last_seen).total_seconds() / 60
                
                # Marcar como offline si no se ha visto en los últimos 5 minutos
                if minutes_since_last_seen > offline_threshold_minutes:
                    device.reference.update({'status': 'offline'})
                    logger.warning(f"Device marked as offline: {device_data['device_id']}")
        
    except Exception as e:
        logger.error(f"Error checking device connectivity: {e}")


if __name__ == '__main__':
    # Para testing local
    test_event = {
        'data': base64.b64encode(json.dumps({
            'device_id': 'test-sensor-001',
            'timestamp': datetime.utcnow().isoformat(),
            'temperature': 25.5,
            'humidity': 65.0,
            'location': 'Rio Principal',
            'latitude': -33.4489,
            'longitude': -70.6693,
            'water_quality_index': 85.5,
        }).encode('utf-8'))
    }
    
    update_firestore(test_event, None)
