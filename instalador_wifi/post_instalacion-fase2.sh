#!/bin/bash
# 🛠️ FASE 2: Compilación nativa del controlador Wi-Fi RTL8189ES (Firma Persistente)

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

# 💡 CORRECCIÓN CRUCIAL: Extraemos el "apellido" del kernel (ej: -current-meson64) 
# Restamos la versión base (6.18.48) del 'uname -r' completo para obtener la etiqueta exacta.
KERNEL_VERSION_BASE=$(echo "$(uname -r)" | cut -d'-' -f1)
KERNEL_LOCALVERSION=$(echo "$(uname -r)" | sed "s/^$KERNEL_VERSION_BASE//")

echo "🏷️ Inyectando firma de versión al módulo: LOCALVERSION=\"$KERNEL_LOCALVERSION\""

# Compilación blindada heredando la firma exacta que exige el Kernel en ejecución
make -j$(nproc) \
  KSRC=/usr/src/linux-headers-$(uname -r) \
  ARCH=arm64 \
  LOCALVERSION="$KERNEL_LOCALVERSION" \
  modules

echo "📦 Moviendo el archivo .ko a la carpeta de módulos del sistema..."
mkdir -p /lib/modules/$(uname -r)/kernel/drivers/net/wireless/

# Usamos cp -f para cumplir con tu estándar de máxima repetibilidad (idempotencia)
cp -f 8189es.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/

# Forzamos la regeneración del mapa de dependencias del sistema y cargamos de forma permanente
echo "🔄 Registrando el módulo de forma permanente en el sistema..."
depmod -a
modprobe 8189es

echo "✅ [ÉXITO] ¡Controlador RTL8189ES levantado con firma persistente y permanente!"
echo "📶 Comprueba tus redes inalámbricas disponibles."
