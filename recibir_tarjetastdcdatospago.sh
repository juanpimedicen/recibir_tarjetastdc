#!/bin/bash
# Script: /usr/src/scripts/ivr/recibir_tarjetastdcdatospago.sh
# Uso: ./recibir_tarjetastdcdatospago.sh "<pagoMinimo>" "<saldoContado>"
# Ej:  ./recibir_tarjetastdcdatospago.sh "0" "160"
#      ./recibir_tarjetastdcdatospago.sh "15.30" "225"
#      ./recibir_tarjetastdcdatospago.sh "15,30" "225"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Uso: $0 \"<pagoMinimo>\" \"<saldoContado>\""
  exit 1
fi

# -------- normalización de montos (acepta coma o punto) --------
normalize_amount() {
  local s="$1"
  s="${s//[[:space:]]/}"
  [[ -z "$s" ]] && { echo "0"; return; }
  s="${s/,/.}"
  [[ "$s" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "0"; return; }
  echo "$s"
}

PAGO_MINIMO="$(normalize_amount "$1")"
SALDO_CONTADO="$(normalize_amount "$2")"

# Rutas base
CONVERTED="/var/opt/motion2/server/files/sounds/converted"
DIGITS="/var/lib/asterisk/sounds/es/digits"

# Audios fijos
A_1099="${CONVERTED}/[1099]-1752614466659"      # Para abonar el pago mínimo, equivalente a
A_1026="${CONVERTED}/[1026]-1754406097542"      # Bolívares y
A_2056="${CONVERTED}/[2056]-1754409695005"      # céntimos
A_2000="${CONVERTED}/[2000]-1752614467500"      # Para abonar el monto total...
A_2001="${CONVERTED}/[2001]-1752614468355"      # Para abonar otro monto...
A_260="${CONVERTED}/[260]-1752615204711"        # marque 1
A_261="${CONVERTED}/[261]-1752615205563"        # marque 2

# ---------- helpers ----------

# Dice 0–999 con tus audios (0 -> vacío; el 0 total se maneja fuera)
say_hundreds_block() {
  local n="$1"; n=$((10#$n))
  if (( n == 0 )); then echo ""; return; fi

  if (( n <= 29 )) || ( ((n < 100)) && ((n % 10 == 0)) ) || ( ((n % 100 == 0)) && (n <= 900) ); then
    echo "'$DIGITS/$n'"; return
  fi

  local out=""
  if (( n >= 100 )); then
    local c=$(( n / 100 ))
    local r=$(( n % 100 ))
    if (( c == 1 )); then out="'$DIGITS/ciento'"; else out="'$DIGITS/${c}00'"; fi
    if (( r > 0 )); then
      if (( r <= 29 )) || ( ((r < 100)) && ((r % 10 == 0)) ); then
        out="$out&'$DIGITS/$r'"
      else
        local d=$(( r / 10 * 10 ))
        local u=$(( r % 10 ))
        out="$out&'$DIGITS/$d'"
        if (( u > 0 )); then out="$out&'$DIGITS/$u'"; fi
      fi
    fi
    echo "$out"; return
  fi

  local d=$(( n / 10 * 10 ))
  local u=$(( n % 10 ))
  out="'$DIGITS/$d'"
  if (( u > 0 )); then out="$out&'$DIGITS/$u'"; fi
  echo "$out"
}

# >>> FIX: Ensamblar de MAYOR a MENOR grupo (millones → miles → centenas) <<<
say_number_big() {
  local num="$1"; num=$((10#$num))
  if (( num == 0 )); then echo "'$DIGITS/0'"; return; fi

  # Partir en grupos de 3
  declare -A parts
  local pos=0 rest="$num"
  while [[ -n "$rest" && "$rest" -ne 0 ]]; do
    local group=$(( rest % 1000 ))
    parts[$pos]=$(printf "%03d" $group)
    rest=$(( rest / 1000 ))
    pos=$((pos+1))
  done

  # Orden DESCENDENTE (clave más alta primero)
  local keys=($(printf "%s\n" "${!parts[@]}" | sort -nr))

  local out=""
  for idx in "${keys[@]}"; do
    local g="${parts[$idx]}"; local gnum=$((10#$g))
    (( gnum == 0 )) && continue
    local frag="$(say_hundreds_block "$gnum")"
    case "$idx" in
      1) frag="$frag&'$DIGITS/thousand'";;
      2) if (( gnum == 1 )); then frag="$frag&'$DIGITS/million'"; else frag="$frag&'$DIGITS/millions'"; fi;;
      3) frag="$frag&'$DIGITS/thousand'&'$DIGITS/millions'";;
      4) if (( gnum == 1 )); then frag="$frag&'$DIGITS/billion'"; else frag="$frag&'$DIGITS/billions'"; fi;;
      5) frag="$frag&'$DIGITS/thousand'&'$DIGITS/billions'";;
    esac
    if [[ -n "$frag" ]]; then
      if [[ -z "$out" ]]; then out="$frag"; else out="$out&$frag"; fi
    fi
  done
  echo "$out"
}

# split_amount: entero|dec (2 dígitos)
split_amount() {
  local amt="$1"
  local fmt; fmt=$(echo "$amt" | awk '{printf "%.2f", $0}')
  local entero="${fmt%.*}"
  local dec="${fmt#*.}"
  echo "$entero|$dec"
}

# Partir en entero y centavos
IFS='|' read -r PM_E PM_C <<< "$(split_amount "$PAGO_MINIMO")"
IFS='|' read -r SC_E SC_C <<< "$(split_amount "$SALDO_CONTADO")"

# Construcción
OUT="'$A_1099'"
OUT="$OUT&$(say_number_big "$PM_E")"
OUT="$OUT&'$A_1026'"
OUT="$OUT&$(say_number_big "$PM_C")&'$A_2056'"
OUT="$OUT&'$A_260'"

OUT="$OUT&'$A_2000'"
OUT="$OUT&$(say_number_big "$SC_E")"
OUT="$OUT&'$A_1026'"
OUT="$OUT&$(say_number_big "$SC_C")&'$A_2056'"
OUT="$OUT&'$A_261'"

OUT="$OUT&'$A_2001'"

echo "$OUT"
