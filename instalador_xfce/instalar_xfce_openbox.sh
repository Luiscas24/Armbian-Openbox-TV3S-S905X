#!/bin/bash
# -------------------------------------------------------------------------
# Script: Instalar XFCE + Openbox en Armbian (Entorno Ultraligero S905X)
# -------------------------------------------------------------------------

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

echo "🔄 1. Actualizando índices de paquetes..."
apt-get update

echo "📦 2. Instalanado XFCE mínimo, Openbox y servidor gráfico..."
# Instalamos solo la base de XFCE sin aplicaciones extra (evita bloatware)
apt-get install -y --no-install-recommends \
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
# Creamos la carpeta de configuración de la sesión del usuario si no existe
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/

# Generamos el archivo de configuración para inyectar Openbox en la sesión de XFCE
cat <<'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="sessions" type="empty">
    <property name="Default" type="empty">
      <property name="Client0_Command" type="array">
        <value type="string" value="openbox"/>
      </property>
      <property name="Client0_PerScreen" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF

echo "📁 4. Creando directorios base de Openbox para el entorno de usuario..."
mkdir -p /etc/xdg/openbox
# Copiamos la configuración global de Openbox si no se ha generado
if [ ! -f /etc/xdg/openbox/rc.xml ]; then
    cp /etc/xdg/openbox/rc.xml /etc/xdg/openbox/rc.xml.bak 2>/dev/null || true
fi

echo "⧉  Copiando y blindando el activador de la consola..."

# 1. Asegurar permisos correctos en la carpeta del instalador antes de mover nada
chown root:root Cambiar_a_modo_consola.desktop Cambiar_a_modo_grafico.sh
chmod 755 Cambiar_a_modo_grafico.sh
chmod 755 Cambiar_a_modo_consola.desktop

# 2. Copiar el lanzador al menú de aplicaciones global del sistema (Protegido por defecto)
cp Cambiar_a_modo_consola.desktop /usr/share/applications/
chown root:root /usr/share/applications/Cambiar_a_modo_consola.desktop
chmod 644 /usr/share/applications/Cambiar_a_modo_consola.desktop

# 3. Averiguar el HOME del usuario real que lanzó el sudo
USER_HOME=$(eval echo "~$SUDO_USER")

# 4. Mover el script .sh al HOME y blindarlo (Escritura exclusiva de Root)
cp Cambiar_a_modo_grafico.sh "$USER_HOME/"
chown root:root "$USER_HOME/Cambiar_a_modo_grafico.sh"
chmod 755 "$USER_HOME/Cambiar_a_modo_grafico.sh"  # <-- Cualquiera lo ejecuta, solo Root lo borra/edita

# 5. Intentar meter el lanzador en el Escritorio o Descargas reales con el mismo blindaje
if [ -d "$USER_HOME/Desktop" ]; then
    DESTINO_DESK="$USER_HOME/Desktop"
elif [ -d "$USER_HOME/Escritorio" ]; then
    DESTINO_DESK="$USER_HOME/Escritorio"
else
    DESTINO_DESK="$USER_HOME"
fi

cp Cambiar_a_modo_consola.desktop "$DESTINO_DESK/"
chown root:root "$DESTINO_DESK/Cambiar_a_modo_consola.desktop"
chmod 755 "$DESTINO_DESK/Cambiar_a_modo_consola.desktop" # <-- Icono protegido en el escritorio

echo "✅ 5. ¡Instalación completada con éxito!"
echo "-------------------------------------------------------------------------"
echo "Ya puedes reiniciar o arrancar el entorno gráfico con: sudo systemctl start lightdm"
echo "-------------------------------------------------------------------------"
