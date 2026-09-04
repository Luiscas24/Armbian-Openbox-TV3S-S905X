#!/bin/bash
# =========================================================================
# 🖥️ PROVISIONADOR: Openbox Estable + Tint2 + PCManFM (Ecosistema Modular S905X)
# 👤 Autor:        Luis Daniel Castellanos Remolina <luisda1583@gmail.com>
# 🤖 Coautor:      Asistente de IA - Gemini - (Bajo estricta dirección arquitectónica)
# 🌐 Repo git:     https://github.com/Luiscas24/armbian-tv3s-toolbox
# 📜 Licencia:     GPL-3.0
# 🛠️ Versión:      1.0.0
# =========================================================================
# Descripción: Automatiza la instalación desatendida de un entorno modular
#              ultraligero basado en Openbox Puro. Delega el escritorio a
#              PCManFM para garantizar el menú contextual tradicional, fuerza
#              a LightDM a usar Openbox e inyecta el activador gráfico.
# =========================================================================

# --- AUTO-SOLICITUD DE PERMISOS ROOT SILENCIOSA (Autogestionada) ---
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS (Blindada para TV Box) ---
DIR_REAL_INSTALADOR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
cd "$DIR_REAL_INSTALADOR"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical

# --- DETECCIÓN DETERMINISTA DEL USUARIO REAL ---
REAL_USER="$SUDO_USER"
[ -z "$REAL_USER" ] && REAL_USER=$(logname 2>/dev/null)
[ -z "$REAL_USER" ] && REAL_USER=$USER
USER_HOME=$(eval echo "~$REAL_USER")

echo "🔄 1. Actualizando índices de paquetes..."
apt-get update

echo "📦 2. Instalando Openbox, Tint2, gestor de escritorio tradicional y servidor gráfico..."
apt-get install -y --no-install-recommends \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    dbus-x11 \
    dbus \
    libpam-systemd \
    xorg \
    xinit \
    openbox \
    obconf \
    tint2 \
    pcmanfm \
    lxterminal \
    lightdm

echo "🏥 3. Inmunizando variables globales de entorno y D-Bus..."
for var in 'XDG_CONFIG_DIRS="/etc/xdg:/etc"' 'XDG_DATA_DIRS="/usr/share:/usr/local/share"'; do
    grep -q "${var%%=*}" /etc/environment || echo "$var" >> /etc/environment
done

rm -f /etc/machine-id /var/lib/dbus/machine-id
dbus-uuidgen --ensure=/etc/machine-id
dbus-uuidgen --ensure 2>/dev/null || true

# =========================================================================
# 🎨 INTEGRACIÓN FÍSICA DEL WALLPAPER LOCAL NATIVO
# =========================================================================
echo "🎨 3.5 Desplegando fondo de pantalla oficial integrado en la suite..."
mkdir -p /usr/share/backgrounds

if [ -f armbian-tv3s-wallpaper.jpg ]; then
    cp armbian-tv3s-wallpaper.jpg /usr/share/backgrounds/Armbian_trianglify_random_blue.jpg
    chmod 644 /usr/share/backgrounds/Armbian_trianglify_random_blue.jpg
else
    echo "⚠️ [INFO] Archivo 'armbian-tv3s-wallpaper.jpg' no encontrado en el origen. Saltando integración visual."
fi

# =========================================================================
# ⚙️ INTEGRACIÓN ATÓMICA: FORZAR SESIÓN POR DEFECTO EN LIGHTDM
# =========================================================================
echo "🔧 Reconfigurando las preferencias globales de LightDM para Openbox..."
sed -i 's/^#user-session=.*/user-session=openbox/' /etc/lightdm/lightdm.conf 2>/dev/null || true
sed -i 's/^user-session=.*/user-session=openbox/' /etc/lightdm/lightdm.conf 2>/dev/null || true

rm -f "$USER_HOME/.dmrc" 2>/dev/null || true
rm -f /root/.dmrc 2>/dev/null || true
rm -f /var/lib/lightdm/.cache/lightdm-gtk-greeter/state 2>/dev/null || true

# =========================================================================
# ⚙️ CONFIGURACIÓN DEL ARRANQUE EN VIVO SECUENCIAL
# =========================================================================
echo "⚙️ 4. Programando inicio de componentes con retardo secuencial..."

mkdir -p "$USER_HOME/.config/openbox"
cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ -x /usr/bin/dbus-launch ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi
sleep 1
tint2 &
pcmanfm --desktop &
EOF

mkdir -p "$USER_HOME/.config/pcmanfm/default"
cat << 'EOF' > "$USER_HOME/.config/pcmanfm/default/desktop-items-0.conf"
[*]
wallpaper_mode=stretch
wallpaper=/usr/share/backgrounds/Armbian_trianglify_random_blue.jpg
desktop_bg=#000000
desktop_fg=#ffffff
show_documents=0
show_trash=0
show_mounts=0
EOF

mkdir -p /root/.config/openbox
cp "$USER_HOME/.config/openbox/autostart" /root/.config/openbox/autostart

mkdir -p /root/.config/pcmanfm/default
cp "$USER_HOME/.config/pcmanfm/default/desktop-items-0.conf" /root/.config/pcmanfm/default/desktop-items-0.conf

chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$USER_HOME/.config"
chown -R root:root /root/.config

# =========================================================================
# 🚀 INYECCIÓN AUTÓNOMA Y ATÓMICA DE 'Cambiar_a_modo_grafico'
# =========================================================================
echo "🚀 Generando e instalando 'Cambiar_a_modo_grafico' de forma global..."
mkdir -p /usr/local/bin

cat << 'EOF' > /usr/local/bin/Cambiar_a_modo_grafico
#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
  exit 1
fi
export XDG_CONFIG_DIRS="/etc/xdg:/etc:/usr/share/desktop-base/profiles/xdg:$XDG_CONFIG_DIRS"
systemctl reload dbus 2>/dev/null || true
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure=/etc/machine-id
dbus-uuidgen --ensure 2>/dev/null || true

REAL_USER="$SUDO_USER"
[ -z "$REAL_USER" ] && REAL_USER=$(logname 2>/dev/null)
[ -z "$REAL_USER" ] && REAL_USER=$USER
REAL_HOME=$(eval echo "~$REAL_USER")

mkdir -p "$REAL_HOME/.config/openbox"
chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$REAL_HOME/.config"

systemctl unmask lightdm 2>/dev/null || true
systemctl enable lightdm 2>/dev/null || true
systemctl isolate graphical.target
systemctl restart lightdm 2>/dev/null || true

MAX_INTENTOS=10
CONTADOR=0
while [ ! -e /tmp/.X11-unix/X0 ] && [ $CONTADOR -lt $MAX_INTENTOS ]; do
    sleep 1
    CONTADOR=$((CONTADOR + 1))
done

chvt 7 2>/dev/null || chvt 1 2>/dev/null

if [ -e /tmp/.X11-unix/X0 ]; then
    DISPLAY=:0 sudo -u "$REAL_USER" notify-send "Armbian TV3S" "¡Interfaz gráfica restaurada con éxito! Openbox y Tint2 están activos."
else
    echo "⚠️ El servidor grafico tardo demasiado en responder."
fi
EOF

chown root:root /usr/local/bin/Cambiar_a_modo_grafico
chmod 755 /usr/local/bin/Cambiar_a_modo_grafico

# =========================================================================
# 📁 5. GESTIÓN DE LANZADORES INVERSOS Y EXCEPCIONES DE PRIVILEGIOS
# =========================================================================
echo "📁 5. Creando directorios base de Openbox para el entorno de usuario..."
mkdir -p /etc/xdg/openbox
if [ -f /etc/xdg/openbox/rc.xml ]; then
    cp /etc/xdg/openbox/rc.xml /etc/xdg/openbox/rc.xml.bak 2>/dev/null || true
fi

echo "🔐 [Seguridad] Configurando excepciones de sudoers para cambios de entorno..."
mkdir -p /etc/sudoers.d
cat << 'EOF' > /etc/sudoers.d/armbian-tv3s-toggle-rules
ALL ALL=(ALL) NOPASSWD: /usr/local/bin/Cambiar_a_modo_grafico
EOF
chmod 0440 /etc/sudoers.d/armbian-tv3s-toggle-rules

echo "⧉  Copiando accesos directos inversos de la suite..."
if [ -f Cambiar_a_modo_consola.desktop ]; then
    chmod 755 Cambiar_a_modo_consola.desktop

    cp Cambiar_a_modo_consola.desktop /usr/share/applications/
    chown root:root /usr/share/applications/Cambiar_a_modo_consola.desktop
    chmod 644 /usr/share/applications/Cambiar_a_modo_consola.desktop

    if [ -d "$USER_HOME/Desktop" ]; then
        DESTINO_DESK="$USER_HOME/Desktop"
    elif [ -d "$USER_HOME/Escritorio" ]; then
        DESTINO_DESK="$USER_HOME/Escritorio"
    else
        DESTINO_DESK="$USER_HOME"
    fi

    cp Cambiar_a_modo_consola.desktop "$DESTINO_DESK/"
    chown root:root "$DESTINO_DESK/Cambiar_a_modo_consola.desktop"
    chmod 755 "$DESTINO_DESK/Cambiar_a_modo_consola.desktop"
else
    echo "⚠️ [INFO] Archivo 'Cambiar_a_modo_consola.desktop' no encontrado en el origen local. Saltando copia."
fi

systemctl enable lightdm
systemctl set-default graphical.target

# =========================================================================
# 🎉 BLOQUE FINAL DE INSTRUCCIONES DE USO ORIGINALES COMPLETO
# =========================================================================
echo "✅ 5. ¡Instalación completada con éxito!"
echo "-------------------------------------------------------------------------"
echo " ¡La interfaz gráfica ahora es un comando nativo del sistema!"
echo " Puede iniciar el entorno desde cualquier terminal ejecutando: Cambiar_a_modo_grafico"
echo " O simplemente reiniciando la TV Box con el comando: sudo reboot"
echo ""
echo " Si necesita volver al modo de solo consola, haga doble clic en el icono"
echo " 'Pasar a Consola Pura' desde su escritorio o menú de aplicaciones."
echo "-------------------------------------------------------------------------"
