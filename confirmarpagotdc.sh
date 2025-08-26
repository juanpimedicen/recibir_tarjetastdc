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

CONVERTED=""
DIGITS="/var/lib/asterisk/sounds/es/digits"

# Audios fijos
A_723="[723]-1752615225781"      # "Usted introdujo"
A_1026="[1026]-1754406097542"    # "Bolívares y"
A_2056="[2056]-1754409695005"    # "céntimos"
A_805="[805]-1752615228467"      # "Para debitar de la cuenta terminada en"
A_1027="[1027]-1752614403059"    # "a la tarjeta de crédito terminada en"
A_1039="[1039]-1752614412501"    # "Si es correcto... marque 1... 2."

# =========================
# Helpers de locución numérica
# =========================

# 0..99 directo (usa archivos 0.gsm..99.gsm)
say_0_99_direct() {
  local n="$1"
  n=$((10#$n))
  echo "'$n'"
}

# 0..999: centenas exactas (100..900) si corresponde; 1xx no exacto -> 'ciento' + (resto 0..99 directo)
say_0_999() {
  local n="$1"
  n=$((10#$n))

  if (( n < 100 )); then
    echo "$(say_0_99_direct "$n")"
    return
  fi

  if (( n % 100 == 0 )) && (( n <= 900 )); then
    echo "'$n'"
    return
  fi

  local c=$(( n / 100 ))     # 1..9
  local r=$(( n % 100 ))     # 1..99
  local out=""
  if (( c == 1 )); then
    out="'ciento'"
  else
    out="'${c}00'"
  fi
  out="$out&$(say_0_99_direct "$r")"
  echo "$out"
}

# Enteros grandes en grupos de 3 + escalas:
# idx=0 unidades, 1 thousand, 2 million(s), 3 thousand&millions, 4 billion(s), 5 thousand&billions
say_integer_large() {
  local n="$1"
  n=$(echo "$n" | sed 's/^0\+\([0-9]\)/\1/')
  [[ -z "$n" ]] && n="0"
  if [[ "$n" == "0" ]]; then echo "'0'"; return; fi

  declare -a groups=()
  local s="$n"
  while [[ -n "$s" ]]; do
    if (( ${#s} > 3 )); then
      groups+=( "${s: -3}" )
      s="${s:0:${#s}-3}"
    else
      groups+=( "$s" )
      s=""
    fi
  done

  local out=""
  local first=1
  for idx in "${!groups[@]}"; do
    local g="${groups[$idx]}"
    local g3
    g3=$(printf "%03d" "$g")
    [[ "$g3" == "000" ]] && continue

    local chunk=""
    case $idx in
      0)  chunk="$(say_0_999 "$g3")" ;;
      1)  if [[ "$g3" == "001" ]]; then
            chunk="'thousand'"
          else
            chunk="$(say_0_999 "$g3")&'thousand'"
          fi ;;
      2)  if [[ "$g3" == "001" ]]; then
            chunk="$(say_0_999 1)&'million'"
          else
            chunk="$(say_0_999 "$g3")&'millions'"
          fi ;;
      3)  if [[ "$g3" == "001" ]]; then
            chunk="'thousand'&'millions'"
          else
            chunk="$(say_0_999 "$g3")&'thousand'&'millions'"
          fi ;;
      4)  if [[ "$g3" == "001" ]]; then
            chunk="$(say_0_999 1)&'billion'"
          else
            chunk="$(say_0_999 "$g3")&'billions'"
          fi ;;
      5)  if [[ "$g3" == "001" ]]; then
            chunk="'thousand'&'billions'"
          else
            chunk="$(say_0_999 "$g3")&'thousand'&'billions'"
          fi ;;
      *)  chunk="$(say_0_999 "$g3")" ;;
    esac

    if (( first )); then
      out="$chunk"
      first=0
    else
      out="$chunk&$out"
    fi
  done

  echo "$out"
}

# Dígitos uno a uno
say_digits() {
  local str="$1"
  local out=""
  local first=1
  for (( i=0; i<${#str}; i++ )); do
    local d="${str:$i:1}"
    if [[ $d =~ [0-9] ]]; then
      if (( first )); then
        out="'$d'"
        first=0
      else
        out="$out&'$d'"
      fi
    fi
  done
  echo "$out"
}

# =========================
# Normalización del monto
# =========================
FMT=$(echo "$MONTO" | awk '{printf "%.2f", $0}')
ENTERO="${FMT%.*}"
CENT="${FMT#*.}"

# Últimos 4 dígitos de cuenta y tarjeta
CUENTA4="${CUENTA: -4}"
TARJETA4="${TARJETA: -4}"

# =========================
# Construcción del READ
# =========================
OUT="'$A_723'"
# Parte entera con escalas
OUT="$OUT&$(say_integer_large "$ENTERO")"
# "Bolívares y"
OUT="$OUT&'$A_1026'"
# Céntimos (00 => 0)
CENT_NUM=$((10#$CENT))
OUT="$OUT&$(say_0_99_direct "$CENT_NUM")&'$A_2056'"

# "Para debitar..." + últimos 4 dígitos (SayDigits)
OUT="$OUT&'$A_805'&$(say_digits "$CUENTA4")"
# "a la tarjeta..." + últimos 4 dígitos (SayDigits)
OUT="$OUT&'$A_1027'&$(say_digits "$TARJETA4")"

# Confirmación final
OUT="$OUT&'$A_1039'"

echo "$OUT"
