# Script: recibir_tarjetas.sh

Este script está diseñado para sistemas Linux (Debian) y permite generar dinámicamente una secuencia de rutas de audio para el comando `READ()` de Asterisk, a partir de un JSON que contiene tarjetas de crédito (TDC). 

El script analiza los últimos 4 dígitos de cada tarjeta, determina la franquicia según el primer dígito, y genera una secuencia de audios que puede reproducirse en una locución IVR.

---

## 📌 Uso

```bash
sh recibir_tarjetas.sh '<json>'
```

- El parámetro debe ser un **string JSON** válido.
- Se procesan como máximo **9 tarjetas**.

---

## 🧾 Formato del JSON esperado

```json
{
  "success": true,
  "message": "Consulta de tarjetas exitosa",
  "data": {
    "tarjetas": [
      {
        "tarjeta": "4862380103007800"
      },
      {
        "tarjeta": "5862380104009940"
      }
    ]
  }
}
```

---

## 🎯 Lógica del script

Por cada tarjeta se genera esta secuencia de audios:

1. **Audio común** según la franquicia:
   - Si el número **empieza por 4** → se usa el audio VISA  
     `/var/opt/motion2/server/files/sounds/converted/[1062]-1752614434060`
   - Si **empieza por 5** → se usa el audio Mastercard  
     `/var/opt/motion2/server/files/sounds/converted/[1083]-1752614452766`

2. **Últimos 4 dígitos** reproducidos uno a uno con:
   ```bash
   /var/lib/asterisk/sounds/es/digits/[DÍGITO]
   ```

3. **Audio “marque X”** según el orden (máximo 9):
   - Por ejemplo, para el primer resultado:
     ```bash
     /var/opt/motion2/server/files/sounds/converted/[260]-1752615204711  # marque 1
     ```

---

## 📤 Salida

Un único string, ideal para usar en:

```asterisk
READ(variable_name, <salida_generada>)
```

Ejemplo de salida:

```bash
'/var/opt/motion2/server/files/sounds/converted/[1062]-1752614434060'&'/var/lib/asterisk/sounds/es/digits/7'&'/var/lib/asterisk/sounds/es/digits/8'&'/var/lib/asterisk/sounds/es/digits/0'&'/var/lib/asterisk/sounds/es/digits/0'&'/var/opt/motion2/server/files/sounds/converted/[260]-1752615204711'
```

---
## Para usar `/usr/src/scripts/ivr/recibir_tarjetastdcact.sh` 
```bash
/usr/src/scripts/ivr/recibir_tarjetastdcact.sh '{
  "success": true,
  "message": "Consulta de tarjetas exitosa",
  "data": {
    "tarjetas": [
      {
        "estatusTarjeta": "5"
      },
      {
        "estatusTarjeta": "1"
      }
    ]
  },
  "code": "000"
}'
```

---

## 🔧 Requisitos

- Sistema basado en **Debian**
- **jq** instalado (`apt install jq`)

---

## ✍️ Autor

Este script fue desarrollado para integraciones avanzadas con Asterisk, orientadas a IVRs personalizados que interactúan con usuarios bancarios.
```
