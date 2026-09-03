#!/bin/bash
# 🛠️ FASE 2: Compilación nativa del controlador Wi-Fi RTL8189ES (Versión Final Blindada)

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

# 🧬 LA CURA: Extraemos el "apellido" y hashes exactos de tu imagen Trunk de Armbian
KERNEL_VERSION_BASE=$(echo "$(uname -r)" | cut -d'-' -f1)
KERNEL_LOCALVERSION=$(echo "$(uname -r)" | sed "s/^$KERNEL_VERSION_BASE//")

echo "🏷️ Inyectando firma de versión al módulo: LOCALVERSION=\"$KERNEL_LOCALVERSION\""

# Compilación blindada heredando la firma exacta que exige tu Kernel en ejecución
make -j$(nproc) \
  KSRC=/usr/src/linux-headers-$(uname -r) \
  ARCH=arm64 \
  LOCALVERSION="$KERNEL_LOCALVERSION" \
  modules

# Validación inmediata del proceso de compilación
if [ $? -ne 0 ]; then
  echo "❌ [ERROR] La compilación falló. Revisa si faltan dependencias o herramientas de build."
  exit 1
fi

echo "📦 Moviendo el archivo .ko a la carpeta de módulos del sistema..."
mkdir -p /lib/modules/$(uname -r)/kernel/drivers/net/wireless/

# Copia forzada para cumplir con el estándar de idempotencia estricta
cp -f 8189es.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
if [ $? -ne 0 ]; then
  echo "❌ [ERROR] No se pudo copiar el archivo .ko al sistema."
  exit 1
fi

echo "🔄 Registrando el módulo de forma permanente en el sistema..."
depmod -a

# =========================================================================
# 🛡️ CANDADO 1: AUDITORÍA DE VERMAGIC FÍSICO (En el disco)
# =========================================================================
VERMAGIC_REAL=$(modinfo -F vermagic /lib/modules/$(uname -r)/kernel/drivers/net/wireless/8189es.ko | awk '{print $1}')
KERNEL_ACTIVO=$(uname -r)

echo "🔬 Auditando consistencia: Módulo ($VERMAGIC_REAL) vs Kernel ($KERNEL_ACTIVO)"

if [ "$VERMAGIC_REAL" != "$KERNEL_ACTIVO" ]; then
  echo "-------------------------------------------------------------------------"
  echo "❌ [CANDADO 1: BLOQUEADO] ¡Falso Positivo detectado en el archivo físico!"
  echo "⚠️ El archivo se compiló con firma: '$VERMAGIC_REAL'"
  echo "⚠️ El sistema exige:                 '$KERNEL_ACTIVO'"
  echo "🛡️  Preservación Forense: El flujo se detiene aquí."
  echo "-------------------------------------------------------------------------"
  exit 1
fi

# Intentamos la carga del módulo con la firma ya corregida
modprobe 8189es

# =========================================================================
# 🔍 CANDADO 2 y 3: AUDITORÍA DE MEMORIA VIVA (En la RAM)
# =========================================================================
# Buscamos en /sys/module/ si el módulo logró inicializarse y está en estado 'live'
if [ ! -d "/sys/module/8189es" ] || [ "$(cat /sys/module/8189es/initstate 2>/dev/null)" != "live" ]; then
  echo "-------------------------------------------------------------------------"
  echo "❌ [CANDADO 2/3: BLOQUEADO] El Kernel bloqueó el módulo en la RAM."
  echo "⚠️  Estado del módulo en el sistema: '$(cat /sys/module/8189es/initstate 2>/dev/null || echo "No cargado")'"
  echo "🛡️  Asepsia en la detección: Falso positivo destruido con éxito."
  echo "-------------------------------------------------------------------------"
  exit 1
fi
# =========================================================================

# SÓLO SI PASA EL DISCO Y LA MEMORIA VIVA OPERATIVA, LLEGAMOS AQUÍ CON UN ÉXITO REAL PERSISTENTE:
echo "✅ [ÉXITO COMPLETO] ¡Controlador RTL8189ES inyectado, activo y en estado LIVE!"
echo "📶 Comprueba tus redes inalámbricas disponibles."
