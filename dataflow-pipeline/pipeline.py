"""
Pipeline de Dataflow para procesamiento de telemetría IoT en tiempo real

Este pipeline:
1. Lee mensajes de Pub/Sub con lecturas de sensores
2. Valida y transforma los datos
3. Calcula agregaciones por ventanas de tiempo
4. Escribe a BigQuery (raw + agregaciones)
5. Hace backup en Cloud Storage
"""

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions
from apache_beam.transforms import window
from apache_beam.io.gcp.bigquery import WriteToBigQuery, BigQueryDisposition
from apache_beam.io.gcp.pubsub import ReadFromPubSub
import json
import logging
import datetime
from typing import Dict, Any, Tuple
import argparse


class SensorReadingSchema:
    """Schema para las lecturas de sensores"""
    
    RAW_SCHEMA = {
        'fields': [
            {'name': 'device_id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'timestamp', 'type': 'TIMESTAMP', 'mode': 'REQUIRED'},
            {'name': 'temperature', 'type': 'FLOAT', 'mode': 'REQUIRED'},
            {'name': 'humidity', 'type': 'FLOAT', 'mode': 'REQUIRED'},
            {'name': 'location', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'latitude', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'longitude', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'water_quality_index', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'metadata', 'type': 'JSON', 'mode': 'NULLABLE'},
            {'name': 'ingestion_timestamp', 'type': 'TIMESTAMP', 'mode': 'REQUIRED'},
        ]
    }
    
    AGGREGATION_SCHEMA = {
        'fields': [
            {'name': 'device_id', 'type': 'STRING', 'mode': 'REQUIRED'},
            {'name': 'window_start', 'type': 'TIMESTAMP', 'mode': 'REQUIRED'},
            {'name': 'window_end', 'type': 'TIMESTAMP', 'mode': 'REQUIRED'},
            {'name': 'location', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'avg_temperature', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'min_temperature', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'max_temperature', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'avg_humidity', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'min_humidity', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'max_humidity', 'type': 'FLOAT', 'mode': 'NULLABLE'},
            {'name': 'reading_count', 'type': 'INTEGER', 'mode': 'REQUIRED'},
            {'name': 'processing_timestamp', 'type': 'TIMESTAMP', 'mode': 'REQUIRED'},
        ]
    }


class ParsePubSubMessage(beam.DoFn):
    """Parsea mensajes de Pub/Sub a diccionarios Python"""

    def process(self, element):
        try:
            logging.info(f"[ParsePubSubMessage] Received raw element: {element[:200] if len(element) > 200 else element}")
            # El mensaje de Pub/Sub viene como bytes
            message_str = element.decode('utf-8')
            logging.info(f"[ParsePubSubMessage] Decoded string: {message_str}")
            data = json.loads(message_str)

            logging.info(f"[ParsePubSubMessage] Successfully parsed message: {data}")
            yield data

        except json.JSONDecodeError as e:
            logging.error(f"[ParsePubSubMessage] Error parsing JSON: {e}, message: {element}")
        except Exception as e:
            logging.error(f"[ParsePubSubMessage] Unexpected error: {e}, element: {element}")


class ValidateAndEnrichData(beam.DoFn):
    """Valida datos y añade metadatos de ingesta"""
    
    TEMP_MIN = -20.0
    TEMP_MAX = 60.0
    HUMIDITY_MIN = 0.0
    HUMIDITY_MAX = 100.0
    
    def setup(self):
        """Ejecutado una vez por worker antes de procesar elementos"""
        import datetime as dt
        self.datetime = dt
    
    def process(self, element: Dict[str, Any]):
        try:
            logging.info(f"[ValidateAndEnrichData] Processing element: {element}")
            # Validar campos requeridos
            required_fields = ['device_id', 'timestamp', 'temperature', 'humidity']
            missing_fields = [field for field in required_fields if field not in element]
            if missing_fields:
                logging.error(f"[ValidateAndEnrichData] REJECTING - Missing required fields: {missing_fields}, element: {element}")
                # No yield - descartar el elemento
            else:
                # Validar rangos de temperatura (pero NO descartar el mensaje)
                temp = float(element['temperature'])
                if not (self.TEMP_MIN <= temp <= self.TEMP_MAX):
                    logging.warning(f"[ValidateAndEnrichData] Temperature out of range: {temp} for device {element['device_id']} - ACCEPTING ANYWAY for debugging")
                    # No return - aceptar el mensaje de todos modos

                # Validar rangos de humedad (pero NO descartar el mensaje)
                humidity = float(element['humidity'])
                if not (self.HUMIDITY_MIN <= humidity <= self.HUMIDITY_MAX):
                    logging.warning(f"[ValidateAndEnrichData] Humidity out of range: {humidity} for device {element['device_id']} - ACCEPTING ANYWAY for debugging")
                    # No return - aceptar el mensaje de todos modos
                
                # Añadir timestamp de ingesta
                element['ingestion_timestamp'] = self.datetime.datetime.utcnow().isoformat()
                
                # Calcular índice de calidad de agua (ejemplo simplificado)
                # En producción, esto sería una fórmula más compleja
                wqi = self._calculate_water_quality_index(temp, humidity)
                element['water_quality_index'] = wqi
                
                # Asegurar que location existe
                if 'location' not in element:
                    element['location'] = 'unknown'

                logging.info(f"[ValidateAndEnrichData] Successfully validated and enriched: {element}")
                yield element

        except (ValueError, TypeError) as e:
            logging.error(f"[ValidateAndEnrichData] Validation error: {e}, element: {element}")
            # No yield - descartar elementos con errores de validación
        except Exception as e:
            logging.error(f"[ValidateAndEnrichData] Unexpected error in validation: {e}, element: {element}")
            # No yield - descartar elementos con errores inesperados
    
    def _calculate_water_quality_index(self, temperature: float, humidity: float) -> float:
        """
        Calcula un índice simplificado de calidad de agua
        En un caso real, esto incluiría más parámetros (pH, oxígeno disuelto, etc.)
        """
        # Normalizar temperatura (óptimo: 15-25°C)
        temp_score = 100 - abs(20 - temperature) * 2
        temp_score = max(0, min(100, temp_score))
        
        # Normalizar humedad (óptimo: 40-60%)
        humidity_score = 100 - abs(50 - humidity)
        humidity_score = max(0, min(100, humidity_score))
        
        # Promedio ponderado
        wqi = (temp_score * 0.6 + humidity_score * 0.4)
        
        return round(wqi, 2)


class AddTimestampDoFn(beam.DoFn):
    """DoFn para agregar timestamp a los elementos"""
    
    def process(self, element):
        import datetime
        from apache_beam.transforms.window import TimestampedValue
        
        timestamp = datetime.datetime.fromisoformat(element['timestamp']).timestamp()
        yield TimestampedValue(element, timestamp)


class FormatForBigQuery(beam.DoFn):
    """Formatea datos para BigQuery"""

    def process(self, element: Dict[str, Any]):
        try:
            logging.info(f"[FormatForBigQuery] Formatting element for BigQuery: {element}")
            formatted = {
                'device_id': str(element['device_id']),
                'timestamp': element['timestamp'],
                'temperature': float(element['temperature']),
                'humidity': float(element['humidity']),
                'location': str(element.get('location', 'unknown')),
                'latitude': float(element['latitude']) if 'latitude' in element else None,
                'longitude': float(element['longitude']) if 'longitude' in element else None,
                'water_quality_index': float(element.get('water_quality_index', 0)),
                'metadata': json.dumps(element.get('metadata', {})),
                'ingestion_timestamp': element['ingestion_timestamp'],
            }

            logging.info(f"[FormatForBigQuery] Successfully formatted for BigQuery: {formatted}")
            yield formatted

        except Exception as e:
            logging.error(f"[FormatForBigQuery] Error formatting for BigQuery: {e}, element: {element}")


class ComputeAggregations(beam.CombineFn):
    """Calcula agregaciones estadísticas por ventana de tiempo"""
    
    def create_accumulator(self):
        return {
            'temperatures': [],
            'humidities': [],
            'device_id': None,
            'location': None,
        }
    
    def add_input(self, accumulator, element):
        accumulator['temperatures'].append(element['temperature'])
        accumulator['humidities'].append(element['humidity'])
        accumulator['device_id'] = element['device_id']
        accumulator['location'] = element.get('location', 'unknown')
        return accumulator
    
    def merge_accumulators(self, accumulators):
        merged = {
            'temperatures': [],
            'humidities': [],
            'device_id': None,
            'location': None,
        }
        
        for acc in accumulators:
            if acc and 'temperatures' in acc:
                merged['temperatures'].extend(acc['temperatures'])
                merged['humidities'].extend(acc['humidities'])
                if merged['device_id'] is None:
                    merged['device_id'] = acc['device_id']
                    merged['location'] = acc['location']
        
        return merged
    
    def extract_output(self, accumulator):
        if not accumulator or 'temperatures' not in accumulator or not accumulator['temperatures']:
            return None
        
        temps = accumulator['temperatures']
        hums = accumulator['humidities']
        
        return {
            'device_id': accumulator['device_id'],
            'location': accumulator['location'],
            'avg_temperature': sum(temps) / len(temps),
            'min_temperature': min(temps),
            'max_temperature': max(temps),
            'avg_humidity': sum(hums) / len(hums),
            'min_humidity': min(hums),
            'max_humidity': max(hums),
            'reading_count': len(temps),
        }


class AddWindowTimestamps(beam.DoFn):
    """Añade timestamps de ventana a las agregaciones"""
    
    def setup(self):
        """Ejecutado una vez por worker antes de procesar elementos"""
        import datetime as dt
        self.datetime = dt
    
    def process(self, element, window=beam.DoFn.WindowParam):
        if element is None:
            return
        
        element['window_start'] = window.start.to_utc_datetime().isoformat()
        element['window_end'] = window.end.to_utc_datetime().isoformat()
        element['processing_timestamp'] = self.datetime.datetime.utcnow().isoformat()
        
        yield element


class FormatForCloudStorage(beam.DoFn):
    """Formatea datos para Cloud Storage (JSON Lines)"""
    
    def process(self, element: Dict[str, Any]):
        try:
            # Convertir a JSON string
            json_str = json.dumps(element, default=str)
            yield json_str
            
        except Exception as e:
            logging.error(f"Error formatting for Cloud Storage: {e}")


def run(argv=None):
    """Pipeline principal"""
    
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--subscription',
        required=True,
        help='Pub/Sub subscription path (projects/PROJECT_ID/subscriptions/SUBSCRIPTION_ID)'
    )
    parser.add_argument(
        '--project',
        required=True,
        help='GCP Project ID'
    )
    parser.add_argument(
        '--region',
        default='us-central1',
        help='GCP Region'
    )
    parser.add_argument(
        '--dataset',
        default='sensor_data',
        help='BigQuery dataset name'
    )
    parser.add_argument(
        '--raw_table',
        default='raw_readings',
        help='BigQuery raw data table name'
    )
    parser.add_argument(
        '--agg_table',
        default='aggregations_minute',
        help='BigQuery aggregations table name'
    )
    parser.add_argument(
        '--output_bucket',
        required=True,
        help='Cloud Storage bucket for backup (gs://bucket-name)'
    )
    parser.add_argument(
        '--window_size',
        type=int,
        default=60,
        help='Window size in seconds for aggregations'
    )
    
    known_args, pipeline_args = parser.parse_known_args(argv)

    # Opciones del pipeline
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(StandardOptions).streaming = True

    # Agregar project y region a las opciones del pipeline
    from apache_beam.options.pipeline_options import GoogleCloudOptions
    google_cloud_options = pipeline_options.view_as(GoogleCloudOptions)
    google_cloud_options.project = known_args.project
    google_cloud_options.region = known_args.region
    
    # Construir el pipeline
    with beam.Pipeline(options=pipeline_options) as p:
        
        # 1. Leer de Pub/Sub
        messages = (
            p 
            | 'Read from Pub/Sub' >> ReadFromPubSub(subscription=known_args.subscription)
            | 'Parse JSON' >> beam.ParDo(ParsePubSubMessage())
        )
        
        # 2. Validar y enriquecer datos
        validated_data = (
            messages
            | 'Validate and Enrich' >> beam.ParDo(ValidateAndEnrichData())
        )
        
        # 3. Escribir datos raw a BigQuery
        _ = (
            validated_data
            | 'Format for BigQuery Raw' >> beam.ParDo(FormatForBigQuery())
            | 'Write Raw to BigQuery' >> WriteToBigQuery(
                table=f'{known_args.project}:{known_args.dataset}.{known_args.raw_table}',
                schema=SensorReadingSchema.RAW_SCHEMA,
                write_disposition=BigQueryDisposition.WRITE_APPEND,
                create_disposition=BigQueryDisposition.CREATE_NEVER,
            )
        )
        
        # 4. Backup a Cloud Storage
        # Comentado temporalmente - WriteToText requiere configuración adicional para streaming
        # _ = (
        #     validated_data
        #     | 'Format for Cloud Storage' >> beam.ParDo(FormatForCloudStorage())
        #     | 'Write to Cloud Storage' >> beam.io.WriteToText(
        #         f'{known_args.output_bucket}/raw-data',
        #         file_name_suffix='.json',
        #         shard_name_template='',
        #         num_shards=10,
        #     )
        # )
        
        # 5. Agregar datos por ventanas de tiempo
        aggregated_data = (
            validated_data
            | 'Add Timestamp' >> beam.ParDo(AddTimestampDoFn())
            | 'Window into Fixed Windows' >> beam.WindowInto(
                window.FixedWindows(known_args.window_size)
            )
            | 'Group by Device' >> beam.Map(lambda x: (x['device_id'], x))
            | 'Group' >> beam.GroupByKey()
            | 'Compute Aggregations' >> beam.CombinePerKey(ComputeAggregations())
            | 'Extract Values' >> beam.Values()
            | 'Add Window Timestamps' >> beam.ParDo(AddWindowTimestamps())
        )
        
        # 6. Escribir agregaciones a BigQuery
        _ = (
            aggregated_data
            | 'Write Aggregations to BigQuery' >> WriteToBigQuery(
                table=f'{known_args.project}:{known_args.dataset}.{known_args.agg_table}',
                schema=SensorReadingSchema.AGGREGATION_SCHEMA,
                write_disposition=BigQueryDisposition.WRITE_APPEND,
                create_disposition=BigQueryDisposition.CREATE_NEVER,
            )
        )


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()
