#!/bin/bash
# =========================================================================
# ⚙️ PROVISIONADOR: Post-Instalación Fase 1 (Kernel & Inmunización de Headers)
# 👤 Autor:        Luis Danie Castellanos Remolina <luisda1583@gmail.com>
# 🤖 Coautor:      Asistente de IA - Gemini - (Bajo estricta dirección arquitectónica)
# 🌐 Repo git:     https://github.com/Luiscas24/Armbian-Openbox-TV3S-S905X
# 📜 Licencia:     GPL-3.0
# 🛠️ Versión:      1.0.0
# =========================================================================
# Descripción: Instala de forma desatendida el ecosistema del kernel y las 
#              herramientas offline. Sincroniza dinámicamente los enlaces de 
#              arranque del chip S905X y repara la receta de los Linux Headers.
# =========================================================================
# 🧾 NOTA DE QA HUMANA / CRÉDITOS:
# * Silenciador Verbose: Ajusta sysctl para mitigar ruido del driver Realtek.
# * Asepsia de Recetas: Sincroniza estructuras nativas previas a compilación.
# =========================================================================

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS (Blindada para TV Box) ---
DIR_REAL_INSTALADOR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR_REAL_INSTALADOR"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
# ----------------------------------------

# =========================================================================
# 🌟 NORMALIZACIÓN DE PERMISOS EN CALIENTE (EJECUTADO EN LA TV BOX)
# =========================================================================
echo "[+] Normalizando la jerarquía de permisos híbridos para la TV Box..."
chown -R root:root "$DIR_REAL_INSTALADOR"
chmod -R u=rwX,go=rX "$DIR_REAL_INSTALADOR"
chmod 644 "$DIR_REAL_INSTALADOR/dependencias_offline"/*.deb 2>/dev/null
chmod 755 "$DIR_REAL_INSTALADOR"/post_instalacion_fase*.sh
# =========================================================================

# =========================================================================
# ⚙️ AJUSTE PERSISTENTE DE LOGS DEL KERNEL (SILENCIA VERBOSE DE REALTEK)
# =========================================================================
echo "⚙️ Ajustando logs del kernel persistentes para no bloquear la interfaz de usuario..."
mkdir -p /etc/sysctl.d
cat << 'EOF' > /etc/sysctl.d/20-silence-realtek.conf
# Bloquea los mensajes ruidosos de depuración del driver en pantalla tras los reinicios
kernel.printk = 3 4 1 3
EOF

# Aplicación inmediata en la RAM actual para la sesión viva
sysctl -w kernel.printk="3 4 1 3"
# =========================================================================

echo "Mandar al driver genérico roto a la lista negra"
# Nota de QA: Se mantiene este echo > limpio ya existente por ser estático y seguro
echo "blacklist rtl8189es" > /etc/modprobe.d/blacklist-rtl8189es.conf

echo "🧹 Asegurando la consistencia de la base de datos local (Offline)..."
sudo dpkg --configure -a

# 📸 FOTOGRAFÍA PREVIA: Capturamos la versión exacta instalada del núcleo objetivo
KERNEL_PKG_ANTES=$(dpkg-query -W -f='${Version}' linux-image-current-meson64 2>/dev/null)

echo "📦 Instalamos las herramientas de forma inteligente usando APT (Offline)..."
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
if [ "$KERNEL_PKG_ANTES" == "$KERNEL_PKG_DESPUES" ] && [ -n "$KERNEL_PKG_DESPUES" ] && [ -f "/boot/Image" ]; then
    echo "[=] [INFO] El paquete 'linux-image-current-meson64' no sufrió modificaciones and /boot/Image está operativo."
    echo "[=] Omitiendo reconfiguración del cargador de arranque para preservar la estabilidad."
else
    echo "[+] Se detectó una instalación inicial o una actualización del núcleo estructural..."
    echo "[+] Sincronizando enlaces de arranque de forma dinámica y adaptable..."
    
    REAL_KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | grep -v "old" | head -n 1)
    REAL_INITRD=$(ls -t /boot/initrd.img-* 2>/dev/null | head -n 1)
    REAL_DTB=$(ls -t /boot/dtb-*/amlogic/meson-gxl-s905x-p212.dtb 2>/dev/null | head -n 1)

    [ -z "$REAL_KERNEL" ] && REAL_KERNEL=$(ls -t /vmlinuz-* 2>/dev/null | head -n 1)
    [ -z "$REAL_INITRD" ] && REAL_INITRD=$(ls -t /initrd.img-* 2>/dev/null | head -n 1)
    [ -z "$REAL_DTB" ] && REAL_DTB=$(ls -t dtb/amlogic/meson-gxl-s905x-p212.dtb 2>/dev/null | head -n 1)

    if [ -n "$REAL_KERNEL" ] && [ -n "$REAL_INITRD" ] && [ -n "$REAL_DTB" ]; then
        echo "[+] Mapeando kernel detectado: $(basename "$REAL_KERNEL")"
        echo "[+] Mapeando initrd detectado: $(basename "$REAL_INITRD")"
        echo "[+] Mapeando DTB detectado: $(basename "$REAL_DTB")"
        
        cp -f "$REAL_KERNEL" /boot/Image 2>/dev/null || cp -f "$REAL_KERNEL" ./Image
        cp -f "$REAL_INITRD" /boot/uInitrd 2>/dev/null || cp -f "$REAL_INITRD" ./uInitrd
        cp -f "$REAL_DTB" /boot/dtb.img 2>/dev/null || cp -f "$REAL_DTB" ./dtb.img
    else
        echo "⚠️ [ERROR] Faltan componentes críticos del nuevo kernel instalados en el disco."
        exit 1
    fi

    CONF_PATH=""
    [ -f "./extlinux/extlinux.conf" ] && CONF_PATH="./extlinux/extlinux.conf"
    [ -f "/boot/extlinux/extlinux.conf" ] && CONF_PATH="/boot/extlinux/extlinux.conf"

    if [ -n "$CONF_PATH" ]; then
        echo "[+] Ajustando parámetros de arranque y herencia de UUID..."
        APPEND_LINE=$(grep -E '^[[:space:]]*append' "$CONF_PATH" | head -n 1 | sed 's/^[[:space:]]*//')
        
        # Inyección atómica de supresión de verbose si el archivo original no lo contempla
        if [[ "$APPEND_LINE" != *"quiet"* ]]; then
            APPEND_LINE="$APPEND_LINE quiet loglevel=3 logo.nologo vt.global_cursor_default=0"
        fi

        CLEAN_DTB=$(echo "$REAL_DTB" | sed -E 's|^\./||; s|^/||')
        NEW_FDT_LINE="fdt /$CLEAN_DTB"

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

# =========================================================================
# 🌟 CIRUGÍA PLÁSTICA DE RAÍZ EN LOS HEADERS (Inmunización de Receta)
# =========================================================================
KERNEL_VERSION_BASE=$(echo "$(uname -r)" | cut -d'-' -f1)
KERNEL_LOCALVERSION=$(echo "$(uname -r)" | sed "s/^$KERNEL_VERSION_BASE//")

echo "🏥 [ASEPSIA DE RAÍZ] Reparando la receta vacía de los Linux Headers..."
echo "🏷️  Estampando sufijo permanente en las recetas: \"$KERNEL_LOCALVERSION\""

if [ -f "/boot/config-$(uname -r)" ]; then
  sudo sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"$KERNEL_LOCALVERSION\"/" /boot/config-$(uname -r)
fi

if [ -f "/usr/src/linux-headers-$(uname -r)/.config" ]; then
  sudo sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"$KERNEL_LOCALVERSION\"/" /usr/src/linux-headers-$(uname -r)/.config
fi

if [ -d "/usr/src/linux-headers-$(uname -r)" ]; then
  echo "🛠️  Sincronizando estructuras nativas de los cabeceras..."
  cd /usr/src/linux-headers-$(uname -r)
  sudo make modules_prepare >/dev/null 2>&1
  sudo make scripts >/dev/null 2>&1
  cd "$DIR_REAL_INSTALADOR"
fi
# =========================================================================

echo "🔄 [AVISO] Ecosistema procesado con éxito."
echo "🔄 La TV Box se reiniciará automáticamente en 5 segundos..."
sleep 5
reboot
