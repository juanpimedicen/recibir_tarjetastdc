#!/bin/bash
# Script: /usr/src/scripts/ivr/confirmarpagotdc.sh
# Uso: ./confirmarpagotdc.sh <monto> <cuenta> <tarjeta>
# Salida: cadena para READ()

if [ $# -ne 3 ]; then
  echo "Uso: $0 <monto> <cuenta> <tarjeta>"
  exit 1
fi

MONTO="$1"
CUENTA="$2"
TARJETA="$3"

CONVERTED="/var/opt/motion2/server/files/sounds/converted"
DIGITS="/var/lib/asterisk/sounds/es/digits"

# Audios fijos
A_723="${CONVERTED}/[723]-1752615225781"
A_1026="${CONVERTED}/[1026]-1754406097542"
A_2056="${CONVERTED}/[2056]-1754409695005"
A_805="${CONVERTED}/[805]-1752615228467"
A_1027="${CONVERTED}/[1027]-1752614403059"
A_1039="${CONVERTED}/[1039]-1752614412501"

# Función para decir números como en SayNumber()
say_number() {
  local n="$1"
  n=$((10#$n))

  if [[ $n -eq 0 ]]; then
    echo "'$DIGITS/0'"
    return
  fi

  if [[ $n -le 29 ]] || (( n < 100 && n % 10 == 0 )) || (( n % 100 == 0 && n <= 900 )); then
    echo "'$DIGITS/$n'"
    return
  fi

  local out=""
  if (( n >= 100 )); then
    local c=$(( n / 100 * 100 ))
    local r=$(( n % 100 ))
    out="'$DIGITS/$c'"
    if (( r > 0 )); then
      if (( r <= 29 )) || (( r < 100 && r % 10 == 0 )); then
        out="$out&'$DIGITS/$r'"
      else
        local d=$(( r / 10 * 10 ))
        local u=$(( r % 10 ))
        out="$out&'$DIGITS/$d'&'$DIGITS/$u'"
      fi
    fi
    echo "$out"
    return
  fi

  local d=$(( n / 10 * 10 ))
  local u=$(( n % 10 ))
  out="'$DIGITS/$d'"
  if (( u > 0 )); then
    out="$out&'$DIGITS/$u'"
  fi
  echo "$out"
}

# Función para decir dígito por dígito (SayDigits)
say_digits() {
  local str="$1"
  local out=""
  local first=1
  for (( i=0; i<${#str}; i++ )); do
    local d="${str:$i:1}"
    if [[ $d =~ [0-9] ]]; then
      if [[ $first -eq 1 ]]; then
        out="'$DIGITS/$d'"
        first=0
      else
        out="$out&'$DIGITS/$d'"
      fi
    fi
  done
  echo "$out"
}

# Normalizar monto a 2 decimales
FMT=$(echo "$MONTO" | awk '{printf "%.2f", $0}')
ENTERO="${FMT%.*}"
CENT="${FMT#*.}"

# Últimos 4 dígitos de cuenta y tarjeta
CUENTA4="${CUENTA: -4}"
TARJETA4="${TARJETA: -4}"

# Construcción del READ
OUT="'$A_723'"
OUT="$OUT&$(say_number "$ENTERO")"
OUT="$OUT&'$A_1026'"
OUT="$OUT&$(say_number "$CENT")"
OUT="$OUT&'$A_2056'"
OUT="$OUT&'$A_805'"
OUT="$OUT&$(say_digits "$CUENTA4")"
OUT="$OUT&'$A_1027'"
OUT="$OUT&$(say_digits "$TARJETA4")"
OUT="$OUT&'$A_1039'"

echo "$OUT"
