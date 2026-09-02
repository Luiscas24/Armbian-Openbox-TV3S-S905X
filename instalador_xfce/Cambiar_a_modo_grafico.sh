#!/bin/bash
# -------------------------------------------------------------------------
# Script: Cambiar entorno a Modo Gráfico (Levantar XFCE + Openbox + LightDM)
# -------------------------------------------------------------------------

# Auto-solicitud de permisos Root
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

echo "🚀 Levantando el servidor gráfico y reviviendo LightDM..."
# Cambia el objetivo del sistema al modo gráfico (activa X11)
systemctl isolate graphical.target

# Enviamos el mensaje al entorno gráfico usando las herramientas nativas de XFCE
DISPLAY=:0 sudo -u $SUDO_USER xfce4-notifyd-config --version >/dev/null 2>&1 && \
DISPLAY=:0 sudo -u $SUDO_USER notify-send "Armbian TV3S" "¡Interfaz gráfica restaurada con éxito! XFCE y Openbox están activos."
