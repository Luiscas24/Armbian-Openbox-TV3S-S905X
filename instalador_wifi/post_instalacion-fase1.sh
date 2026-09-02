#!/bin/bash
# 🛠️ FASE 1: Instalación del ecosistema del kernel y herramientas offline

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS (Blindada para TV Box) ---
# Usamos BASH_SOURCE para capturar la ruta absoluta real del instalador antes de que APT se maree
DIR_REAL_INSTALADOR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR_REAL_INSTALADOR"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
# ----------------------------------------

# =========================================================================
# 🌟 NORMALIZACIÓN DE PERMISOS EN CALIENTE (EJECUTADO EN LA TV BOX)
# =========================================================================
echo "[+] Normalizando la jerarquía de permisos híbridos para la TV Box..."
# 1. Aseguramos que root del dispositivo sea dueño de todo el directorio copiado
chown -R root:root "$DIR_REAL_INSTALADOR"

# 2. El truco de la 'X' mayúscula recursiva:
# Da acceso 755 a todas las subcarpetas (incluyendo el driver y debs) para exploración universal,
# pero preserva los archivos planos (.c, .h) con permisos sanos sin ejecuciones falsas.
chmod -R u=rwX,go=rX "$DIR_REAL_INSTALADOR"

# 3. Forzamos permiso de lectura pura (644) exclusivamente a los paquetes .deb.
# Esto asegura que el usuario del sistema '_apt' de Armbian los lea sin Permission Denied.
chmod 644 "$DIR_REAL_INSTALADOR/dependencias_offline"/*.deb 2>/dev/null

# 4. Aseguramos que los scripts principales retengan sus derechos de ejecución (755)
chmod 755 "$DIR_REAL_INSTALADOR"/post_instalacion_fase*.sh
# =========================================================================

echo "Ajusta los logs del kernel para que no bloqueen la interfaz de usuario"
sysctl -w kernel.printk="3 4 1 3"

echo "Mandar al driver genérico roto a la lista negra"
echo "blacklist rtl8189es" > /etc/modprobe.d/blacklist-rtl8189es.conf

echo "🧹 Asegurando la consistencia de la base de datos local (Offline)..."
# Este comando repara cualquier paquete que haya quedado a medias en un intento previo
sudo dpkg --configure -a

# 📸 FOTOGRAFÍA PREVIA: Capturamos la versión exacta instalada del núcleo objetivo
KERNEL_PKG_ANTES=$(dpkg-query -W -f='${Version}' linux-image-current-meson64 2>/dev/null)

echo "📦 Instalamos las herramientas de forma inteligente usando APT (Offline)..."
# 🌟 Usamos la ruta absoluta calculada para que APT encuentre la carpeta sin importar el PWD de root
sudo apt install -y --no-install-recommends "$DIR_REAL_INSTALADOR/dependencias_offline"/*.deb
if [ $? -ne 0 ]; then
    echo "[-] ERROR: Hubo un problema crítico al procesar los paquetes con APT."
    exit 1
fi

echo ""

# 📸 FOTOGRAFÍA POSTERIOR: Verificamos el estado del paquete tras el comando de APT
KERNEL_PKG_DESPUES=$(dpkg-query -W -f='${Version}' linux-image-current-meson64 2>/dev/null)

# =========================================================================
# 🔄 INICIO DEL BLOQUE DE ADAPTACIÓN DINÁMICA DEL ARRANQUE
# =========================================================================

# 🔍 VALIDACIÓN ATÓMICA DEFINITIVA: ¿El kernel-image sufrió cambios reales?
if [ "$KERNEL_PKG_ANTES" == "$KERNEL_PKG_DESPUES" ] && [ -n "$KERNEL_PKG_DESPUES" ] && [ -f "/boot/Image" ]; then
    echo "[=] [INFO] El paquete 'linux-image-current-meson64' no sufrió modificaciones y /boot/Image está operativo."
    echo "[=] Omitiendo reconfiguración del cargador de arranque para preservar la estabilidad."
else
    echo "[+] Se detectó una instalación inicial o una actualización del núcleo estructural..."
    echo "[+] Sincronizando enlaces de arranque de forma dinámica y adaptable..."
    
    # 1. Buscamos el kernel, initrd y DTB más recientes usando 'ls -t' (ordena por fecha)
    REAL_KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | grep -v "old" | head -n 1)
    REAL_INITRD=$(ls -t /boot/initrd.img-* 2>/dev/null | head -n 1)
    REAL_DTB=$(ls -t /boot/dtb-*/amlogic/meson-gxl-s905x-p212.dtb 2>/dev/null | head -n 1)

    # Respaldos si la partición de la imagen guarda las cosas directo en la raíz de la tarjeta
    [ -z "$REAL_KERNEL" ] && REAL_KERNEL=$(ls -t /vmlinuz-* 2>/dev/null | head -n 1)
    [ -z "$REAL_INITRD" ] && REAL_INITRD=$(ls -t /initrd.img-* 2>/dev/null | head -n 1)
    [ -z "$REAL_DTB" ] && REAL_DTB=$(ls -t dtb/amlogic/meson-gxl-s905x-p212.dtb 2>/dev/null | head -n 1)

    # 2. Forzamos la clonación segura sobre las rutas estáticas fijas (/Image, /uInitrd y /dtb.img)
    if [ -n "$REAL_KERNEL" ] && [ -n "$REAL_INITRD" ] && [ -n "$REAL_DTB" ]; then
        echo "[+] Mapeando kernel detectado: $(basename "$REAL_KERNEL")"
        echo "[+] Mapeando initrd detectado: $(basename "$REAL_INITRD")"
        echo "[+] Mapeando DTB detectado: $(basename "$REAL_DTB")"
        
        # Copias de seguridad en cascada hacia las dos ubicaciones comunes
        cp -f "$REAL_KERNEL" /boot/Image 2>/dev/null || cp -f "$REAL_KERNEL" ./Image
        cp -f "$REAL_INITRD" /boot/uInitrd 2>/dev/null || cp -f "$REAL_INITRD" ./uInitrd
        cp -f "$REAL_DTB" /boot/dtb.img 2>/dev/null || cp -f "$REAL_DTB" ./dtb.img

        # 💡 MITIGACIÓN CRÍTICA: Se eliminaron las líneas destructivas 'find /boot/ ... -exec rm -f {} +'
        # Mantener las fuentes originales vmlinuz e initrd evita corromper la base de datos de APT.
    else
        echo "⚠️ [ERROR] Faltan componentes críticos del nuevo kernel instalados en el disco."
        exit 1
    fi

    # 3. Localizamos el archivo extlinux.conf de forma dinámica para corregir sus líneas
    CONF_PATH=""
    [ -f "./extlinux/extlinux.conf" ] && CONF_PATH="./extlinux/extlinux.conf"
    [ -f "/boot/extlinux/extlinux.conf" ] && CONF_PATH="/boot/extlinux/extlinux.conf"

    if [ -n "$CONF_PATH" ]; then
        echo "[+] Ajustando parámetros de arranque y herencia de UUID..."
        APPEND_LINE=$(grep -E '^[[:space:]]*append' "$CONF_PATH" | head -n 1 | sed 's/^[[:space:]]*//')
        
        # Limpiamos la ruta eliminando prefijos de entorno para U-Boot nativo
        CLEAN_DTB=$(echo "$REAL_DTB" | sed -E 's|^\./||; s|^/||')
        NEW_FDT_LINE="fdt /$CLEAN_DTB"

        # 4. Reescribimos el archivo manteniendo la compatibilidad que U-Boot clónico exige
        cat <<EOF > "$CONF_PATH"
label Armbian_community
  kernel /Image
  initrd /uInitrd
  $NEW_FDT_LINE
  $APPEND_LINE
EOF
        echo "[+] ¡Arranque blindado y adaptado dinámicamente con éxito!"
    else
        echo "⚠️ [ALERTA] No se encontró el archivo de configuración extlinux.conf."
    fi
fi
# =========================================================================
# 🔄 FIN DEL BLOQUE DE ADAPTACIÓN DINÁMICA DEL ARRANQUE
# =========================================================================

echo "🔄 [AVISO] Ecosistema procesado con éxito."
echo "🔄 La TV Box se reiniciará automáticamente en 5 segundos..."
sleep 5
reboot
