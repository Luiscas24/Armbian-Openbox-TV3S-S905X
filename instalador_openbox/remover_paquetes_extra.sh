#!/bin/bash
# Script de limpieza para mantener el ecosistema minimalista

echo "🧹 Removiendo paquetes no autorizados..."

# 1. Desinstalar paquetes específicos agregados fuera de especificación
sudo apt-get purge -y \
  libasound2 \
  libcanberra* \
  libgtk-4* \
  libgraphene* \
  pulseaudio-utils

# 2. Limpieza profunda de dependencias huerfanas y archivos huérfanos
echo "🧼 Limpiando dependencias no utilizadas..."
sudo apt-get autoremove --purge -y
sudo apt-get clean

echo "✅ Sistema restaurado al estado minimalista original."
