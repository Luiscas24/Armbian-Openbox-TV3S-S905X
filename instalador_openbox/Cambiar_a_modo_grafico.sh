#!/bin/bash
# =========================================================================
# 🎛️ PROVISIONADOR: Cambiar entorno a Modo Grafico (Levantar Openbox + Tint2)
# 👤 Autor:        Luis Daniel Castellanos Remolina <luisda1583@gmail.com>
# 🤖 Coautor:      Asistente de IA - Gemini - (Bajo estricta dirección de QA humana)
# 🌐 Repo git:     https://github.com/Luiscas24/Armbian-Openbox-TV3S-S905X
# 📜 Licencia:     GPL-3.0
# 🛠️ Versión:      1.0.0
# =========================================================================

# --- 🔐 AUTO-SOLICITUD DE PERMISOS ROOT SILENCIOSA ---
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
  exit 1
fi

echo "🧬 Sincronizando el bus de mensajes del sistema (D-Bus) y variables de /etc..."

# 1. Forzar de forma inmediata las rutas de configuración para la sesión actual
export XDG_CONFIG_DIRS="/etc/xdg:/etc:/usr/share/desktop-base/profiles/xdg:$XDG_CONFIG_DIRS"

# 2. Reestablecer de forma segura la firma de la máquina y recargar el bus
systemctl reload dbus 2>/dev/null || true
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure=/etc/machine-id
dbus-uuidgen --ensure 2>/dev/null || true

# 3. Detección dinámica y robusta del usuario (sin nombres fijos cableados)
REAL_USER="$SUDO_USER"
[ -z "$REAL_USER" ] && REAL_USER=$(logname 2>/dev/null)
[ -z "$REAL_USER" ] && REAL_USER=$USER
REAL_HOME=$(eval echo "~$REAL_USER")

# Saneamos la ruta del autostart modular de Openbox para el usuario activo
mkdir -p "$REAL_HOME/.config/openbox"
chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$REAL_HOME/.config"

echo "🔄 Asegurando dependencias de ejecución previas al arranque gráfico..."
systemctl unmask lightdm 2>/dev/null || true
systemctl enable lightdm 2>/dev/null || true

echo "🚀 Levantando el servidor gráfico y reviviendo LightDM..."
systemctl isolate graphical.target
systemctl restart lightdm 2>/dev/null || true

# --- BUCLE DE ESPERA ACTIVA (Sincronización de visualización en el chip S905X) ---
echo "⏳ Esperando la inicialización del servidor X11 (DISPLAY :0)..."
MAX_INTENTOS=10
CONTADOR=0
while [ ! -e /tmp/.X11-unix/X0 ] && [ $CONTADOR -lt $MAX_INTENTOS ]; do
    sleep 1
    CONTADOR=$((CONTADOR + 1))
done

# Forzar el refresco de asignación de la terminal gráfica (Evita bloqueo en negro)
chvt 7 2>/dev/null || chvt 1 2>/dev/null

# Enviamos la notificación de éxito al entorno gráfico a través del servidor X activo
if [ -e /tmp/.X11-unix/X0 ]; then
    DISPLAY=:0 sudo -u "$REAL_USER" notify-send "Armbian TV3S" "¡Interfaz gráfica restaurada con éxito! Openbox y Tint2 están activos."
    echo "✅ ¡Modo gráfico inicializado correctamente!"
else
    echo "⚠️ [ADVERTENCIA] El servidor gráfico tardó demasiado en responder. Si no ve video, intente reiniciar la TV Box."
fi
