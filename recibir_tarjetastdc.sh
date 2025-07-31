#!/bin/sh

# Verificación del parámetro
if [ $# -ne 1 ]; then
  echo "Uso: $0 '<json>'"
  exit 1
fi

INPUT_JSON="$1"

# Definición de rutas
AUDIO_VISA="/var/opt/motion2/server/files/sounds/converted/[1062]-1752614434060"
AUDIO_MC="/var/opt/motion2/server/files/sounds/converted/[1083]-1752614452766"
DIGITS_PATH="/var/lib/asterisk/sounds/es/digits"

# Mapeo de audios "marque X"
MARQUE_BASE="/var/opt/motion2/server/files/sounds/converted"
MARQUE_CODES="[260]-1752615204711 [261]-1752615205563 [262]-1752615206416 [263]-1752615207245 [264]-1752615208213 [265]-1752615209184 [266]-1752615210139 [267]-1752615210967 [268]-1752615211846"

# Convertir lista a array
IFS=' ' read -r -a MARQUE_ARRAY <<EOF
$MARQUE_CODES
EOF

# Procesar tarjetas con jq + awk
echo "$INPUT_JSON" | jq -r '.data.tarjetas[0:9][] | .tarjeta' | awk -v visa="$AUDIO_VISA" -v mc="$AUDIO_MC" -v digits="$DIGITS_PATH" -v marque_base="$MARQUE_BASE" '
BEGIN {
  count = 0
}
{
  gsub(/ /, "", $0)
  if (length($0) < 4) next

  count++
  prefix = substr($0, 1, 1)
  last4 = substr($0, length($0)-3, 4)

  audio = (prefix == "4") ? visa : mc

  printf "'\''%s'\''", audio

  for (i = 1; i <= 4; i++) {
    digit = substr(last4, i, 1)
    printf "&'\''%s/%s'\''", digits, digit
  }

  if (count <= 9) {
    split("'"'"'"MARQUE_CODES"'"'"'", marque_list, " ")
    printf "&'\''%s/%s'\''", marque_base, marque_list[count]
  }

  if (count < 9 && !eof) {
    printf "&"
  }
}
END {
  print ""
}'
