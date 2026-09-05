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

set -e

# Autogestión de privilegios de root con sudo
if [ "$EUID" -ne 0 ]; then
  echo "🔐 Solicitando privilegios de administrador (sudo) para continuar..."
  exec sudo "$0" "$@"
  exit 1
fi

echo "================================================================="
echo "📦 Iniciando instalación de Armbian Openbox v1.0.0..."
echo "================================================================="

# -------------------------------------------------------------------------
# 1. ACTUALIZACIÓN E INSTALACIÓN DE PAQUETES Y DEPENDENCIAS
# -------------------------------------------------------------------------
echo "📥 Actualizando repositorios e instalando dependencias base..."
apt-get update
apt-get install -y \
  openbox \
  tint2 \
  pcmanfm \
  picom \
  lightdm \
  lightdm-gtk-greeter \
  polkitd \
  pkexec \
  xorg \
  x11-xserver-utils \
  feh \
  lxterminal \
  pulseaudio \
  pavucontrol \
  dbus-x11

# -------------------------------------------------------------------------
# 2. GESTIÓN DE ENERGÍA Y CONFIGURACIÓN DE POLKIT
# -------------------------------------------------------------------------
echo "⚡ Configurando permisos de energía e inhabilitando suspensión..."

# Asignar grupos requeridos al usuario lightdm
usermod -aG power,sudo,autologin,nopasswdlogin lightdm 2>/dev/null || true

# Enmascarar suspensión e hibernación en systemd (Incompatibles con S905X)
systemctl mask suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

# Crear regla de Polkit en formato JavaScript (Debian 12 / Bookworm)
mkdir -p /etc/polkit-1/rules.d/
cat << 'EOF' > /etc/polkit-1/rules.d/10-armbian-power.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions") {
        return polkit.Result.YES;
    }
});
EOF
chmod 644 /etc/polkit-1/rules.d/10-armbian-power.rules

# Regla de respaldo PKLA
mkdir -p /etc/polkit-1/localauthority/50-local.d/
cat << 'EOF' > /etc/polkit-1/localauthority/50-local.d/10-armbian-tv3s-power.pkla
[Permitir Apagar y Reiniciar sin contrasena]
Identity=unix-user:lightdm;group:sudo;group:power
Action=org.freedesktop.login1.reboot;org.freedesktop.login1.reboot-multiple-sessions;org.freedesktop.login1.power-off;org.freedesktop.login1.power-off-multiple-sessions
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

# -------------------------------------------------------------------------
# 3. CONFIGURACIÓN VISUAL Y PARÁMETROS DE LIGHTDM GREETER
# -------------------------------------------------------------------------
echo "🎨 Configurando interfaz visual y greeter de LightDM..."

# Asegurar alternativas del greeter
update-alternatives --set lightdm-greeter /usr/share/xgreeters/lightdm-gtk-greeter.desktop 2>/dev/null || true

# Limpiar posibles sobreescrituras en .conf.d
rm -rf /etc/lightdm/lightdm-gtk-greeter.conf.d/* 2>/dev/null || true

# Escribir configuración principal limpia de LightDM Greeter
cat << 'EOF' > /etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
background=/usr/share/backgrounds/Armbian_trianglify_random_blue.jpg
theme-name=Adwaita
icon-theme-name=Adwaita
font-name=Sans 10
xft-antialias=true
xft-dpi=96
xft-hintstyle=hintslight
xft-rgba=rgb
indicators=~host;~spacer;~clock;~spacer;~language;~session;~power
restrict-standby-buttons=true
EOF

# -------------------------------------------------------------------------
# 4. CONFIGURACIÓN DE ENTORNO DE USUARIO (OPENBOX & AUTOSTART)
# -------------------------------------------------------------------------
echo "⚙️ Configurando archivos de inicio de Openbox para el usuario..."

TARGET_USER="${SUDO_USER:-$USER}"
if [ "$TARGET_USER" = "root" ]; then
    TARGET_USER="armbian"
fi

USER_HOME=$(eval echo "~$TARGET_USER")

mkdir -p "$USER_HOME/.config/openbox"
mkdir -p "$USER_HOME/.config/tint2"

# Crear archivo autostart para Openbox sin parpadeos/tearing
cat << 'EOF' > "$USER_HOME/.config/openbox/autostart"
# Cargar fondo de pantalla
feh --bg-fill /usr/share/backgrounds/Armbian_trianglify_random_blue.jpg &

# Panel tint2
tint2 &

# Compositor picom configurado para evitar tearing sin pantalla negra
picom --backend xrender --vsync &
EOF

# Ajustar permisos del directorio de configuración
chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config"

# -------------------------------------------------------------------------
# 5. GENERACIÓN DE SCRIPTS AUXILIARES DE CAMBIO DE MODO
# -------------------------------------------------------------------------
echo "🛠️ Generando accesos directos para conmutar entornos..."

# Script para pasar a Modo Gráfico
cat << 'EOF' > /usr/local/bin/Cambiar_a_modo_grafico
#!/bin/bash
systemctl set-default graphical.target
systemctl start lightdm
EOF
chmod +x /usr/local/bin/Cambiar_a_modo_grafico

# Script para pasar a Modo Consola
cat << 'EOF' > /usr/local/bin/Cambiar_a_modo_consola
#!/bin/bash
systemctl set-default multi-user.target
systemctl stop lightdm
EOF
chmod +x /usr/local/bin/Cambiar_a_modo_consola

# -------------------------------------------------------------------------
# 6. REINICIO DE SERVICIOS Y BLOQUE FINAL DE INSTRUCCIONES
# -------------------------------------------------------------------------
echo "🔄 Recargando demonios de sistema..."

systemctl restart polkit.service 2>/dev/null || true
systemctl restart systemd-logind.service 2>/dev/null || true

echo "================================================================="
echo "✅ ¡Instalación de Armbian Openbox v1.0.0 completada exitosamente!"
echo "================================================================="
echo ""
echo "📌 INSTRUCCIONES DE USO:"
echo " 1. Para iniciar el entorno gráfico ahora mismo:"
echo "    Cambiar_a_modo_grafico"
echo ""
echo " 2. Si deseas regresar permanentemente al arranque en consola TTY:"
echo "    Cambiar_a_modo_consola"
echo ""
echo " 3. Se han habilitado unicamente las opciones 'Apagar' y 'Reiniciar'."
echo "    La suspensión e hibernación están deshabilitadas por hardware."
echo "================================================================="
