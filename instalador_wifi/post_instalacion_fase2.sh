#!/bin/bash
# 🧪 SCRIPT EN MODO PRUEBA DE QA: Triple Candado Forense Completo y Control Atómico

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

echo "🛠️ Compilando el controlador Realtek de forma nativa sobre el kernel actual ($(uname -r))..."
cd ./rtl8189ES_linux

if [ -f "Makefile" ]; then
  echo "🧹 Limpiando residuos de compilaciones anteriores..."
  make clean >/dev/null 2>&1
fi

# =========================================================================
# ⚠️ TU LÍNEA DE COMPILACIÓN ORIGINAL (Mantiene el fallo real del Vermagic)
# =========================================================================
make -j$(nproc) KSRC=/usr/src/linux-headers-$(uname -r) ARCH=arm64 modules

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
# 🛡️ CANDADO 1: AUDITORÍA DE VERMAGIC AVANZADA (Fidelidad en Disco)
# =========================================================================
# Capturamos la cadena completa, limpiando espacios invisibles redundantes
VERMAGIC_REAL=$(modinfo -F vermagic /lib/modules/$(uname -r)/kernel/drivers/net/wireless/8189es.ko | awk '{$1=$1; print}')
KERNEL_ACTIVO=$(uname -r)

echo "🔬 [AUDITORÍA DE TEXTO] Inspeccionando consistencia cruda:"
echo "   ➔ String en Disco:  '$VERMAGIC_REAL'"
echo "   ➔ Exigencia Kernel: '$KERNEL_ACTIVO'"

# Doble corchete para manejo atómico de espacios. El patrón == * * valida match parcial exacto.
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
