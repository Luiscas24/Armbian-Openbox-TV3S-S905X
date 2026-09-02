#!/bin/bash
# -------------------------------------------------------------------------
# Script: Cambiar entorno gráfico a Consola Pura (Liberar RAM al Máximo)
# -------------------------------------------------------------------------

# Auto-solicitud de permisos Root
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

echo "🛑 Deteniendo LightDM y liberando recursos de la GPU/RAM..."
# Cambia el objetivo del sistema al modo multiusuario (consola pura sin X11)
systemctl isolate multi-user.target

echo "✅ Modo consola activado. Si estás en la TV box física, presiona Ctrl+Alt+F1 si no ves el prompt."
