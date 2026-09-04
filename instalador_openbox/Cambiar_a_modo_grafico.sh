#!/bin/bash
# =========================================================================
# 🎛️ PROVISIONADOR: Cambiar entorno a Modo Gráfico (Levantar XFCE + Openbox)
# 👤 Autor:        Luis Danie Castellanos Remolina <luisda1583@gmail.com>
# 🤖 Coautor:      Asistente de IA - Gemini - (Bajo estricta dirección de QA humana)
# 🌐 Repo git:     https://github.com/Luiscas24/armbian-tv3s-toolbox 
# 📜 Licencia:     GPL-3.0
# 🛠️ Versión:      1.0.4
# =========================================================================

# --- 🔐 AUTO-SOLICITUD DE PERMISOS ROOT SILENCIOSA ---
if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
  exit 1
fi

# =========================================================================
# 🛡️ INYECCIÓN DE ENTORNOS GLOBALES (SOLUCIÓN COMPLETA AL CUADRO AMARILLO)
# =========================================================================
echo "🧬 Sincronizando el bus de mensajes del sistema (D-Bus) y variables de /etc..."

# 1. Forzar de forma inmediata las rutas de configuración para la sesión actual
export XDG_CONFIG_DIRS="/etc/xdg:/etc:/usr/share/desktop-base/profiles/xdg:$XDG_CONFIG_DIRS"

# 2. Reestablecer de forma segura la firma de la máquina y recargar el bus
systemctl reload dbus >/dev/null 2>&1
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure=/etc/machine-id
dbus-uuidgen --ensure >/dev/null 2>&1

# 3. Detección dinámica y robusta del usuario (sin nombres fijos cableados)
REAL_USER="$SUDO_USER"
[ -z "$REAL_USER" ] && REAL_USER=$(logname 2>/dev/null)
[ -z "$REAL_USER" ] && REAL_USER=$USER
REAL_HOME=$(eval echo "~$REAL_USER")

mkdir -p "$REAL_HOME/.config/xfce4"
chown -R "$REAL_USER:$(id -gn "$REAL_USER")" "$REAL_HOME/.config"
# =========================================================================

echo "🔄 Asegurando dependencias de ejecución previas al arranque gráfico..."
# Forzar que el servicio lightdm esté limpio y habilitado
systemctl unmask lightdm 2>/dev/null || true
systemctl enable lightdm 2>/dev/null || true

echo "🚀 Levantando el servidor gráfico y reviviendo LightDM..."
# En kernels de TV Box, reiniciar explícitamente el display manager en lugar de solo aislar
# mitiga que Xorg se cuelgue intentando tomar control de la tty activa.
systemctl isolate graphical.target
systemctl restart lightdm 2>/dev/null || true

# --- BUCLE DE ESPERA ACTIVA (Sincronización de Señal de Video) ---
echo "⏳ Esperando la inicialización del servidor X11 (DISPLAY :0)..."
MAX_INTENTOS=10
CONTADOR=0
while [ ! -e /tmp/.X11-unix/X0 ] && [ $CONTADOR -lt $MAX_INTENTOS ]; do
    sleep 1
    CONTADOR=$((CONTADOR + 1))
done

# Forzar el refresco de asignación de la terminal gráfica (Evita pantalla negra bloqueada)
chvt 7 2>/dev/null || chvt 1 2>/dev/null

# Enviamos la notificación de éxito al entorno gráfico vivo únicamente si el servidor X respondió
if [ -e /tmp/.X11-unix/X0 ]; then
    DISPLAY=:0 sudo -u "$REAL_USER" xfce4-notifyd-config --version >/dev/null 2>&1 && \
    DISPLAY=:0 sudo -u "$REAL_USER" notify-send "Armbian TV3S" "¡Interfaz gráfica restaurada con éxito! XFCE y Openbox están activos."
    echo "✅ ¡Modo gráfico inicializado correctamente!"
else
    echo "⚠️ [ADVERTENCIA] El servidor gráfico tardó demasiado en responder. Si no ve video, intente reiniciar la TV Box."
fi
