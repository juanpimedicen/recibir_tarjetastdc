#!/bin/bash
# Script: /usr/src/scripts/ivr/recibir_tarjetastdcdatospago.sh
# Uso: ./recibir_tarjetastdcdatospago.sh '<json_de_una_tarjeta>'
# Salida: cadena para READ() uniendo audios con &

# Validación de entrada
if [ -z "$1" ]; then
  echo "Uso: $0 '<json_de_una_tarjeta>'"
  exit 1
fi

JSON="$1"

# Rutas base
CONVERTED="/var/opt/motion2/server/files/sounds/converted"
DIGITS="/var/lib/asterisk/sounds/es/digits"

# Audios fijos
A_1099="${CONVERTED}/[1099]-1752614466659"      # "Para abonar el pago mínimo, equivalente a"
A_1026="${CONVERTED}/[1026]-1754406097542"      # "Bolívares y"
A_2056="${CONVERTED}/[2056]-1754409695005"      # "céntimos"
A_2000="${CONVERTED}/[2000]-1752614467500"      # "Para abonar el monto total de la deuda, equivalente a"
A_2001="${CONVERTED}/[2001]-1752614468355"      # "Para abonar otro monto, marque 3"
A_260="${CONVERTED}/[260]-1752615204711"        # "marque 1"
A_261="${CONVERTED}/[261]-1752615205563"        # "marque 2"

# ---------- helpers ----------

# say_number: compone números como en SayNumber() usando librería digits (no dígito a dígito)
# Soporta: 0-29, decenas (30,40,...,90), centenas exactas (100,200,...,900),
# y combinaciones simples (e.g., 125 = 100 & 25; 34 = 30 & 4).
say_number() {
  local n="$1"
  # normalizar a entero (por si llega "007")
  if [[ -z "$n" ]]; then n=0; fi
  n=$((10#$n))

  # 0 directo
  if [[ $n -eq 0 ]]; then
    echo "'$DIGITS/0'"
    return
  fi

  # 1..29 (directo)
  if [[ $n -le 29 ]]; then
    echo "'$DIGITS/$n'"
    return
  fi

  # decenas exactas 30..90
  if (( n < 100 )) && (( n % 10 == 0 )); then
    echo "'$DIGITS/$n'"
    return
  fi

  # centenas exactas 100..900
  if (( n >= 100 )) && (( n % 100 == 0 )) && (( n <= 900 )); then
    echo "'$DIGITS/$n'"
    return
  fi

  local out=""
  if (( n >= 100 )); then
    local c=$(( n / 100 * 100 ))      # 345 -> 300
    local r=$(( n % 100 ))            #       45
    out="'$DIGITS/$c'"
    if (( r > 0 )); then
      # r puede ser 1..99; intentamos directo si <=29 o decena exacta
      if (( r <= 29 )) || (( r < 100 && r % 10 == 0 )); then
        out="$out&'$DIGITS/$r'"
      else
        # 31..99 no múltiplos de 10 -> decena + unidad
        local d=$(( r / 10 * 10 ))
        local u=$(( r % 10 ))
        out="$out&'$DIGITS/$d'&'$DIGITS/$u'"
      fi
    fi
    echo "$out"
    return
  fi

  # 30..99 no múltiplos de 10 -> decena + unidad
  local d=$(( n / 10 * 10 ))
  local u=$(( n % 10 ))
  out="'$DIGITS/$d'"
  if (( u > 0 )); then
    out="$out&'$DIGITS/$u'"
  fi
  echo "$out"
}

# split_amount: recibe un número (int/float) y devuelve entero y decimal (2 dígitos)
split_amount() {
  local amt="$1"
  # normalizar a 2 decimales con awk (locale-safe)
  local fmt
  fmt=$(echo "$amt" | awk '{printf "%.2f", $0}')
  local entero="${fmt%.*}"
  local dec="${fmt#*.}"
  echo "$entero|$dec"
}

# ---------- extraer montos ----------
PAGO_MINIMO=$(echo "$JSON" | jq -r '.pagoMinimo // 0')
SALDO_CONTADO=$(echo "$JSON" | jq -r '.saldoContado // 0')

# Si vienen como strings vacíos, forzar 0
[[ -z "$PAGO_MINIMO" ]] && PAGO_MINIMO=0
[[ -z "$SALDO_CONTADO" ]] && SALDO_CONTADO=0

# Partir en entero y centavos (pad a 2 dígitos)
IFS='|' read -r PM_E PM_C <<< "$(split_amount "$PAGO_MINIMO")"
IFS='|' read -r SC_E SC_C <<< "$(split_amount "$SALDO_CONTADO")"

# Construcción
# Bloque 1: pago mínimo
OUT="'$A_1099'"

# entero pago mínimo
OUT="$OUT&$(say_number "$PM_E")"
# "Bolívares y"
OUT="$OUT&'$A_1026'"
# céntimos pago mínimo (decimales como número compuesto)
OUT="$OUT&$(say_number "$PM_C")&'$A_2056'"
# marque 1
OUT="$OUT&'$A_260'"

# Bloque 2: monto total (saldo contado)
OUT="$OUT&'$A_2000'"
OUT="$OUT&$(say_number "$SC_E")"
OUT="$OUT&'$A_1026'"
OUT="$OUT&$(say_number "$SC_C")&'$A_2056'"
# marque 2
OUT="$OUT&'$A_261'"

# Bloque 3: otro monto, marque 3
OUT="$OUT&'$A_2001'"

echo "$OUT"

