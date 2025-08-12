#!/bin/bash

# Script: recibir_tarjetastdcact.sh
# Uso: /usr/src/scripts/ivr/recibir_tarjetastdcact.sh '<json>'
# Retorna: true o false

JSON_INPUT="$1"

# Verificar que el JSON no esté vacío
if [ -z "$JSON_INPUT" ]; then
  echo "false"
  exit 1
fi

# Contar cuántas tarjetas hay
CARD_COUNT=$(echo "$JSON_INPUT" | jq '.data.tarjetas | length')

# Verificar si hay más de una tarjeta
if [ "$CARD_COUNT" -gt 1 ]; then
  # Verificar si al menos una tiene estatusTarjeta = "1"
  HAS_ACTIVE=$(echo "$JSON_INPUT" | jq '.data.tarjetas[] | select(.estatusTarjeta == "1")' | jq -s 'length')
  
  if [ "$HAS_ACTIVE" -gt 0 ]; then
    echo "true"
    exit 0
  fi
fi

echo "false"
