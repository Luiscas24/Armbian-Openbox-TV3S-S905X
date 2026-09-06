#!/bin/bash
# =====================================================================
# SCRIPT DE COMPILACIÓN AUTOMATIZADA - RTL8189ES (UNIVERSAL & ROBUSTO)
# =====================================================================

# =====================================================================
# CONFIGURACIÓN MANUAL AVANZADA (Opcional)
# Si por alguna razón la auto-detección del sistema no encuentra tu pin 
# GPIO o prefieres forzar uno específico tras hacer ingeniería inversa 
# del hardware, puedes escribirlo aquí (ej. GPIO_PIN_MANUAL="48"). 
# Si se deja vacío, el script intentará detectarlo solo o compilará 
# en modo estándar a velocidad baja garantizando conectividad.
# =====================================================================
GPIO_PIN_MANUAL="" 

echo "[+] Iniciando preparación para el driver RTL8189ES..."

# --- FASE 1: INTENTAR AUTO-DETECCIÓN ---
WIFI_PIN_NUMBER=""

for gpiochip_dir in /sys/class/gpio/gpiochip*; do
    if [ -d "$gpiochip_dir" ]; then
        BASE_PIN=$(cat "$gpiochip_dir/base")
        N_GPIOS=$(cat "$gpiochip_dir/ngpio")
        
        if [ "$BASE_PIN" -lt 400 ] && [ "$N_GPIOS" -gt 0 ]; then
            WIFI_PIN_NUMBER=$((BASE_PIN + 10))
            break
        fi
    fi
done

# --- FASE 2: RESOLUCIÓN DE PRIORIDAD (Automático vs Manual) ---
if [ -z "$WIFI_PIN_NUMBER" ] && [ ! -z "$GPIO_PIN_MANUAL" ]; then
    WIFI_PIN_NUMBER="$GPIO_PIN_MANUAL"
    echo "[+] Usando PIN GPIO manual definido en el script: $WIFI_PIN_NUMBER"
elif [ ! -z "$WIFI_PIN_NUMBER" ]; then
    echo "[+] Usando PIN GPIO detectado automáticamente: $WIFI_PIN_NUMBER"
fi

# --- FASE 3: COMPILACIÓN CONDICIONAL ---
if [ ! -z "$WIFI_PIN_NUMBER" ]; then
    echo "[+] Compilando con alta velocidad (Optimizado con GPIO $WIFI_PIN_NUMBER)..."
    EXTRA_CFLAGS="-DCONFIG_RTL8189ES_GPIO_INDEX=$WIFI_PIN_NUMBER"
else
    echo "[-] No se encontró pin GPIO automático ni manual."
    echo "[+] Compilando en modo estándar (velocidad baja, conectividad garantizada)..."
    EXTRA_CFLAGS=""
fi

# Comando de compilación del driver
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CONFIG_RTL8189ES=m EXTRA_CFLAGS="$EXTRA_CFLAGS"
