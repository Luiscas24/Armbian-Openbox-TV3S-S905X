#!/bin/bash
# 🛠️ FASE 2: Compilación nativa del controlador Wi-Fi RTL8189ES

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS ---
# Guardamos la ruta absoluta del directorio base para movernos de forma segura
DIR_BASE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$DIR_BASE"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
# ----------------------------------------

# =========================================================================
# 🌟 INICIALIZACIÓN DE HEADERS NATIVOS (SOLUCIÓN AL ERROR DE MODULES)
# =========================================================================
echo "🛠️ Despertando y preparando los scripts de arquitectura para el nuevo kernel ($(uname -r))..."
# Nos movemos a la carpeta de los headers recién instalados bajo el nuevo kernel
cd /usr/src/linux-headers-$(uname -r)

# Preparamos el entorno interno y compilamos las herramientas nativas (como fixdep)
make modules_prepare >/dev/null 2>&1
make scripts >/dev/null 2>&1

# Regresamos de forma segura a la carpeta raíz de nuestro instalador
cd "$DIR_BASE"
# =========================================================================

echo "🛠️ Compilando el controlador Realtek de forma nativa sobre el kernel actual ($(uname -r))..."
cd ./rtl8189ES_linux

# 💡 MITIGACIÓN EXTRA: Limpieza preventiva para que segundas pasadas no arrastren binarios corruptos
if [ -f "Makefile" ]; then
  echo "🧹 Limpiando residuos de compilaciones anteriores..."
  make clean >/dev/null 2>&1
fi

# Compilación optimizada usando todos los núcleos del S905X
make -j$(nproc) KSRC=/usr/src/linux-headers-$(uname -r) ARCH=arm64 modules

# El 'cp' crucial para inyectar el módulo en caliente
echo "📦 Moviendo el archivo .ko a la carpeta de módulos del sistema..."
# 💡 MITIGACIÓN EXTRA: Aseguramos que la carpeta exista por si el nuevo kernel vino vacío
mkdir -p /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
cp 8189es.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/

# Actualizar el mapa de dependencias y activar el módulo
depmod -a
modprobe 8189es

echo "✅ [ÉXITO] ¡Controlador RTL8189ES levantado de forma nativa y en caliente!"
echo "📶 Comprueba tus redes inalámbricas disponibles."
