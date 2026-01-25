#!/bin/bash

# Script para enviar mensajes de prueba al sistema IoT
# Uso: ./send-test-message.sh [cantidad]

set -e

PROJECT_ID="potent-odyssey-480320-k4"
TOPIC="sensor-telemetry"
COUNT=${1:-1}

echo "================================================"
echo " Enviando $COUNT mensaje(s) de prueba"
echo "================================================"
echo ""

for i in $(seq 1 $COUNT); do
  # Generar valores aleatorios
  TEMP=$(awk -v min=15 -v max=35 'BEGIN{srand(); print min+rand()*(max-min)}')
  HUM=$(awk -v min=40 -v max=80 'BEGIN{srand(); print min+rand()*(max-min)}')
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  DEVICE_ID="test-device-$(printf "%03d" $((RANDOM % 10 + 1)))"

  # Crear mensaje JSON
  MESSAGE_JSON=$(cat <<EOF
{
  "device_id": "${DEVICE_ID}",
  "temperature": ${TEMP},
  "humidity": ${HUM},
  "timestamp": "${TIMESTAMP}",
  "location": "Test Lab",
  "latitude": 40.7128,
  "longitude": -74.0060
}
EOF
)

  # Mostrar información
  printf "[$i/$COUNT] Enviando: %s | Temp: %.1f°C | Hum: %.1f%%\n" \
    "$DEVICE_ID" "$TEMP" "$HUM"

  # Enviar mensaje
  gcloud pubsub topics publish ${TOPIC} \
    --project=${PROJECT_ID} \
    --message="$MESSAGE_JSON" \
    --quiet

  # Pequeña pausa entre mensajes
  if [ $i -lt $COUNT ]; then
    sleep 0.5
  fi
done

echo ""
echo "✓ $COUNT mensaje(s) enviado(s) exitosamente"
echo ""
echo "Para verificar los datos en BigQuery (espera ~30 segundos):"
echo "  make test-verify"
echo ""
echo "Para ver el dashboard de Dataflow:"
echo "  https://console.cloud.google.com/dataflow/jobs?project=${PROJECT_ID}"
