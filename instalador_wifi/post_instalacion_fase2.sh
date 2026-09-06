#!/bin/bash
# =========================================================================
# ⚙️ PROVISIONADOR: Post-Instalación Fase 2 (Compilación e Inmunización de Driver)
# 👤 Autor:        Luis Danie Castellanos Remolina <luisda1583@gmail.com>
# 🤖 Coautor:      Asistente de IA - Gemini - (Bajo estricta dirección arquitectónica)
# 🌐 Repo git:     https://github.com/Luiscas24/Armbian-Openbox-TV3S-S905X
# 📜 Licencia:     GPL-3.0
# 🛠️ Versión:      1.0.0
# =========================================================================
# Descripción: Prepara las cabeceras nativas de arquitectura, extirpa rutinas 
#              de ahorro energético (IPS/LPS) inyectando parches al código C,
#              compila el módulo de red RTL8189ES y ejecuta una auditoría secuencial
#              de triple candado de seguridad en disco y memoria RAM.
# =========================================================================
# 🧾 NOTA DE QA HUMANA / CRÉDITOS:
# * Extirpación Binaria: Zapa las banderas de CONFIG_POWER_SAVING en Makefiles/Headers.
# * Triple Candado OS: Valida Vermagic en almacenamiento, retorno CLI y estado RAM.
# =========================================================================

# =====================================================================
# DETECCIÓN E INYECCIÓN DIRECTA - RTL8189ES
# =====================================================================

set -e

# =====================================================================
# CONFIGURACIÓN: Deja vacío para auto-detección, o pon un número manual
# =====================================================================
MANUAL_WIFI_PIN=""
WIFI_LINE=""

if [ -n "$MANUAL_WIFI_PIN" ]; then
    echo "[+] Usando pin GPIO configurado manualmente: $MANUAL_WIFI_PIN"
    WIFI_LINE="$MANUAL_WIFI_PIN"
else
    echo "[+] Buscando la línea de control Wi-Fi en el hardware..."
    # -----------------------------------------------------------------
    # TU SEGMENTO DE DETECCIÓN INTACTO (NO SE TOCA)
    if command -v gpioinfo &> /dev/null; then
        WIFI_LINE=$(gpioinfo | grep -E 'consumer="cd"|consumer=cd' | sed -E 's/.*line[[:space:]]+([0-9]+).*/\1/')
    fi
    # -----------------------------------------------------------------
fi

# =====================================================================
# GESTIÓN CONDICIONAL DE EXTRA_CFLAGS
# =====================================================================
EXTRA_CFLAGS_PARAM=""

if [ -n "$WIFI_LINE" ]; then
    echo "[+] Pin GPIO validado con éxito -> $WIFI_LINE"
    EXTRA_CFLAGS_PARAM="-DCONFIG_RTL8189ES_GPIO_INDEX=$WIFI_LINE"
else
    echo "[-] Aviso: No se detectó pin por hardware ni se ingresó valor manual."
    echo "[-] Los flags de GPIO quedarán vacíos y el driver compilará con sus valores por defecto."
fi

# ====================================================================

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS ---
DIR_BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$DIR_BASE"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
# ----------------------------------------

# =========================================================================
# 🌟 INICIALIZACIÓN DE HEADERS NATIVOS (SOLUCIÓN AL ERROR DE MODULES)
# =========================================================================
echo "🛠️ Despertando y preparando los scripts de arquitectura para el nuevo kernel ($(uname -r))..."
cd /usr/src/linux-headers-$(uname -r)

make modules_prepare >/dev/null 2>&1
make scripts >/dev/null 2>&1

cd "$DIR_BASE"
# =========================================================================

echo "🛠️ Preparando el entorno del controlador Realtek nativo..."
cd ./rtl8189ES_linux

if [ -f "Makefile" ]; then
  echo "🧹 Limpiando residuos de compilaciones anteriores..."
  make clean >/dev/null 2>&1
  
  # =========================================================================
  # 💉 INYECCIÓN DE ESTABILIDAD ANTIAHORRO EN CÓDIGO FUENTE (CAPA BINARIA)
  # =========================================================================
  echo "🧬 Extirpando rutinas de ahorro de energía (IPS/LPS) directamente del código C..."
  
  # Forzar bandera a 'n' en cualquier archivo de construcción o configuración
  find . -type f \( -name "Makefile" -o -name "autoconf.h" -o -name "Kconfig" \) -exec sed -i 's/CONFIG_POWER_SAVING = y/CONFIG_POWER_SAVING = n/g' {} +
  find . -type f \( -name "Makefile" -o -name "autoconf.h" -o -name "Kconfig" \) -exec sed -i 's/CONFIG_POWER_SAVING\s*=.*y/CONFIG_POWER_SAVING = n/g' {} +
  
  # Desactivar las definiciones del preprocesador C para asegurar consistencia
  find . -type f -name "autoconf.h" -exec sed -i 's/#define CONFIG_POWER_SAVING/\/\/ #define CONFIG_POWER_SAVING/g' {} +
  # =========================================================================
fi

set -e

# =====================================================================
# ⚙️ COMPILACIÓN DEL CONTROLADOR (Binario ya inmunizado contra IPS/LPS)
# =====================================================================
echo "[+] Iniciando la compilación del driver RTL8189ES..."

echo "🛠️ Compilando el controlador Realtek sobre el kernel actual ($(uname -r))..."
make -j$(nproc) KSRC=/usr/src/linux-headers-$(uname -r) ARCH=arm64 EXTRA_CFLAGS="$EXTRA_CFLAGS_PARAM" modules

# 1. VALIDACIÓN INMEDIATA DE LA COMPILACIÓN
if [ $? -ne 0 ]; then
  echo "❌ [ERROR] La compilación falló. Revisa si faltan dependencias o herramientas de build."
  exit 1
fi

echo "📦 Moviendo el archivo .ko a la carpeta de módulos del sistema..."
mkdir -p /lib/modules/$(uname -r)/kernel/drivers/net/wireless/

# 2. VALIDACIÓN INMEDIATA DE LA COPIA FÍSICA
cp -f 8189es.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
if [ $? -ne 0 ]; then
  echo "❌ [ERROR] No se pudo copiar el archivo .ko al sistema."
  exit 1
fi

echo "🔄 Registrando el módulo de forma permanente en el sistema..."
depmod -a

# =========================================================================
# ⚙️ PARÁMETRO DE ESTABILIDAD OS: DIRECTIVAS PARA MODPROBE
# =========================================================================
echo "⚙️ Creando reglas de persistencia para el gestor de módulos (modprobe.d)..."
mkdir -p /etc/modprobe.d

cat << 'EOF' > /etc/modprobe.d/8189es.conf
# Archivo generado automáticamente para asegurar estabilidad sin fricción de usuario
options 8189es rtw_power_mgnt=0 rtw_ips_mode=0 rtw_lps_enable=0
EOF

if [ $? -ne 0 ]; then
  echo "❌ [ERROR] No se pudo escribir la configuración de estabilidad en /etc/modprobe.d/"
  exit 1
fi
# =========================================================================

# =========================================================================
# 🎛️ CONFIGURACIÓN GLOBAL DEL GESTOR DE RED DEL OS (EVITA SUSPENSIÓN POR SOFTWARE)
# =========================================================================
if [ -d "/etc/NetworkManager/conf.d" ]; then
  echo "📡 Blindando NetworkManager contra comandos de suspensión inalámbrica..."
  cat << 'EOF' > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
[connection]
# 2 desactiva por completo el ahorro de energía en la interfaz a nivel de sistema operativo
wifi.powersave=2
EOF
  systemctl restart NetworkManager >/dev/null 2>&1
fi
# =========================================================================

# =========================================================================
# 🛡️ CANDADO 1: AUDITORÍA DE VERMAGIC AVANZADA (Fidelidad en Disco)
# =========================================================================
VERMAGIC_REAL=$(modinfo -F vermagic /lib/modules/$(uname -r)/kernel/drivers/net/wireless/8189es.ko | awk '{$1=$1; print}')
KERNEL_ACTIVO=$(uname -r)

echo "🔬 [AUDITORÍA DE TEXTO] Inspeccionando consistencia cruda:"
echo "   ➔ String en Disco:  '$VERMAGIC_REAL'"
echo "   ➔ Exigencia Kernel: '$KERNEL_ACTIVO'"

if [[ "$VERMAGIC_REAL" != *"$KERNEL_ACTIVO"* ]]; then
  echo "-------------------------------------------------------------------------"
  echo "❌ [CANDADO 1: DETENIDO EN SECO] ¡Falso Positivo detectado en disco!"
  echo "⚠️ La firma grabada en el binario y la del Kernel vivo no hacen match."
  echo "🛡️  Preservación Forense del Estado: El flujo se frena antes de la RAM."
  echo "-------------------------------------------------------------------------"
  exit 1
fi
# =========================================================================

# =========================================================================
# ⚡ EJECUCIÓN DEL COMANDO CRÍTICO Y CAPTURA INMEDIATA DE ESTADO
# =========================================================================
echo "⚡ Intentando la carga del módulo con modprobe..."
modprobe 8189es
CODIGO_SALIDA_REAL=$? # 🛡️ Captura atómica instantánea.

# =========================================================================
# 🛡️ CANDADO 2: EL SEMÁFORO DE INYECCIÓN CLI
# =========================================================================
if [ $CODIGO_SALIDA_REAL -ne 0 ]; then
  echo "-------------------------------------------------------------------------"
  echo "❌ [CANDADO 2: DETENIDO] modprobe devolvió un código de error real ($CODIGO_SALIDA_REAL)."
  echo "⚠️ El Kernel rechazó físicamente el binario en la terminal."
  echo "🛡️  Asepsia en la detección: Se detiene el flujo."
  echo "-------------------------------------------------------------------------"
  exit 1
fi
# =========================================================================

# =========================================================================
# 🔍 CANDADO 3: AUDITORÍA DE MEMORIA VIVA OPERATIVA (En la RAM)
# =========================================================================
INIT_STATE=$(cat /sys/module/8189es/initstate 2>/dev/null || echo "inexistente")
echo "🔬 Estado de inicialización en RAM: '$INIT_STATE'"

if [ "$INIT_STATE" != "live" ]; then
  echo "-------------------------------------------------------------------------"
  echo "❌ [CANDADO 3: DETENIDO] Módulo en estado inválido o inexistente en RAM."
  echo "🛡️  Aislamiento de la Escena del Fallo: Abortando despliegue."
  echo "-------------------------------------------------------------------------"
  exit 1
fi
# =========================================================================

# SÓLO SI LOS TRES CANDADOS PASAN EN ESTRICTO ORDEN SECUENCIAL, LLEGAMOS AL ÉXITO REAL:
echo "✅ [ÉXITO COMPLETO] ¡Controlador RTL8189ES levantado con firma persistente y permanente!"
echo "📶 Comprueba tus redes inalámbricas disponibles."
