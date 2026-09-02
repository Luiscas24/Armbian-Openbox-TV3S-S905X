#!/bin/bash
# -------------------------------------------------------------------------
# Script: Instalar XFCE + Openbox en Armbian (Entorno Ultraligero S905X)
# Propósito: Aprovisionamiento ágil para TV Boxes y Sticks Donados
# -------------------------------------------------------------------------

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS (Blindada para TV Box) ---
DIR_REAL_INSTALADOR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
cd "$DIR_REAL_INSTALADOR"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
# ----------------------------------------

echo "🔄 1. Actualizando índices de paquetes..."
apt-get update

echo "📦 2. Instalando XFCE mínimo, Openbox y servidor gráfico..."
# Añadimos la barra de progreso nativa manteniendo la salida de texto para el técnico
apt-get install -y --no-install-recommends \
    -o Dpkg::Progress-Fancy="1" \
    xfce4-session \
    xfce4-panel \
    xfdesktop4 \
    xfce4-terminal \
    thunar \
    xorg \
    xinit \
    openbox \
    obconf \
    lightdm

echo "⚙️ 3. Configurando Openbox como el gestor de ventanas predeterminado de XFCE..."
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/

# Generamos el archivo de configuración para inyectar Openbox manteniendo Panel y Escritorio
cat <<'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="sessions" type="empty">
    <property name="Default" type="empty">
      <property name="Client0_Command" type="array">
        <value type="string" value="openbox"/>
      </property>
      <property name="Client0_PerScreen" type="bool" value="false"/>
      <property name="Client1_Command" type="array">
        <value type="string" value="xfce4-panel"/>
      </property>
      <property name="Client1_PerScreen" type="bool" value="false"/>
      <property name="Client2_Command" type="array">
        <value type="string" value="xfdesktop"/>
      </property>
      <property name="Client2_PerScreen" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF

echo "📁 4. Creando directorios base de Openbox para el entorno de usuario..."
mkdir -p /etc/xdg/openbox
# Blindaje Idempotente: Solo respalda el rc.xml original de fábrica la primera vez
if [ -f /etc/xdg/openbox/rc.xml ] && [ ! -f /etc/xdg/openbox/rc.xml.bak ]; then
    cp /etc/xdg/openbox/rc.xml /etc/xdg/openbox/rc.xml.bak 2>/dev/null || true
fi

echo "⧉  Copiando y blindando el activador de la consola..."

chown root:root Cambiar_a_modo_consola.desktop Cambiar_a_modo_grafico.sh
chmod 755 Cambiar_a_modo_grafico.sh
chmod 755 Cambiar_a_modo_consola.desktop

# Copias forzadas (-f) para permitir ejecuciones repetidas sin interrupción
cp -f Cambiar_a_modo_consola.desktop /usr/share/applications/
chown root:root /usr/share/applications/Cambiar_a_modo_consola.desktop
chmod 644 /usr/share/applications/Cambiar_a_modo_consola.desktop

USER_HOME=$(eval echo "~$SUDO_USER")

cp -f Cambiar_a_modo_grafico.sh "$USER_HOME/"
chown root:root "$USER_HOME/Cambiar_a_modo_grafico.sh"
chmod 755 "$USER_HOME/Cambiar_a_modo_grafico.sh"

if [ -d "$USER_HOME/Desktop" ]; then
    DESTINO_DESK="$USER_HOME/Desktop"
elif [ -d "$USER_HOME/Escritorio" ]; then
    DESTINO_DESK="$USER_HOME/Escritorio"
else
    DESTINO_DESK="$USER_HOME"
fi

cp -f Cambiar_a_modo_consola.desktop "$DESTINO_DESK/"
chown root:root "$DESTINO_DESK/Cambiar_a_modo_consola.desktop"
chmod 755 "$DESTINO_DESK/Cambiar_a_modo_consola.desktop"

systemctl enable lightdm
systemctl set-default graphical.target

echo "✅ 5. ¡Instalación completada con éxito!"
echo "-------------------------------------------------------------------------"
echo "Puede iniciar el entorno gráfico ejecutando ./Cambiar_a_modo_grafico.sh"
echo "desde el directorio de su usuario, o reiniciando la TV Box con: sudo reboot"
echo "Si necesita volver al modo de solo consola haga doble click en Cambiar_a_modo_consola"
echo "desde su escritorio o menú de aplicaciones"
echo "-------------------------------------------------------------------------"
