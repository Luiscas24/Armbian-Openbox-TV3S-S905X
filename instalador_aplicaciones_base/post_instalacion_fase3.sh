#!/bin/bash
# =========================================================================
# ⚙️ PROVISIONADOR: Post-Instalación Fase 3 (Ecosistema de Software Modular & UX)
# 👤 Autor:        Luis Danie Castellanos Remolina <luisda1583@gmail.com>
# 🤖 Coautor:      Asistente de IA - Gemini - (Bajo estricta dirección arquitectónica)
# 🌐 Repo git:     https://github.com
# 📜 Licencia:     GPL-3.0
# 🛠️ Versión:      1.0.3
# =========================================================================
# Descripción: Script secuencial y opcional. Inyecta la suite MVP de 
#              productividad y despliega los accesos directos en Openbox.
#              Las descripciones se centran estrictamente en la función.
# =========================================================================
# 🧾 NOTA DE QA HUMANA / CRÉDITOS:
# * Diseño Selectivo: Permite al usuario omitir bloques para proteger la MicroSD.
# * Enfoque Nativo: Descripciones funcionales puras sin referencias externas.
# =========================================================================

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS ---
DIR_REAL_INSTALADOR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
cd "$DIR_REAL_INSTALADOR"

export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin

# Detectar el usuario real detrás de sudo para aplicar los cambios en su Home
USUARIO_REAL=${SUDO_USER:-$USER}
HOME_USUARIO=$(eval echo ~$USUARIO_REAL)
MENU_OPENBOX="$HOME_USUARIO/.config/openbox/menu.xml"
# ----------------------------------------

# =========================================================================
# 🛡️ VALIDACIÓN PREVENTIVA DE ESPACIO EN LA TARJETA MICROSD
# =========================================================================
ESPACIO_DISPONIBLE_KB=$(df / | awk 'NR==2 {print $4}')
ESPACIO_MINIMO_REQUERIDO_KB=3145728 # ~3 GB en Kilobytes

echo "🔬 [AUDITORÍA DE DISCO] Verificando almacenamiento disponible en la MicroSD..."
if [ "$ESPACIO_DISPONIBLE_KB" -lt "$ESPACIO_MINIMO_REQUERIDO_KB" ]; then
  echo "-------------------------------------------------------------------------"
  echo "⚠️ [ALERTA DE ESPACIO CRÍTICO] Quedan menos de 3GB libres en la MicroSD."
  echo "   Instalar toda la suite de software podría congelar o bloquear el sistema."
  echo "   Se recomienda encarecidamente instalar SOLO los componentes vitales."
  echo "-------------------------------------------------------------------------"
  echo -n "¿Deseas continuar bajo tu propio riesgo? (s/n): "
  read -r RESPUESTA_DISCO
  if [[ ! "$RESPUESTA_DISCO" =~ ^[Ss]$ ]]; then
    echo "❌ Despliegue cancelado para preservar la integridad del almacenamiento."
    exit 1
  fi
fi

# Asegurar que exista el directorio de configuración de Openbox del usuario
mkdir -p "$(dirname "$MENU_OPENBOX")"
# Si el archivo menu.xml no existe, creamos una estructura base mínima
if [ ! -f "$MENU_OPENBOX" ]; then
  cat << 'EOF' > "$MENU_OPENBOX"
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org">
  <menu id="apps-menu" title="Aplicaciones">
    <!-- INYECCION_AUTOMATICA -->
  </menu>
</openbox_menu>
EOF
  chown "$USUARIO_REAL:$USUARIO_REAL" "$MENU_OPENBOX"
fi

echo "========================================================================="
echo "📦 ASISTENTE DE INSTALACIÓN DE SOFTWARE MODULAR"
echo "========================================================================="
echo "Responde con 's' (Sí) o 'n' (No) a cada uno de los siguientes bloques."
echo "-------------------------------------------------------------------------"

# =========================================================================
# 📦 BLOQUE 1: CORE DE NAVEGACIÓN, OFIMÁTICA Y MULTIMEDIA (NATIVOS)
# =========================================================================
# Desactivamos temporalmente la expansión por historial (!) por seguridad en el script
set +H

echo ""
echo "👉 BLOQUE 1: Herramientas del Dia a Dia (Fase de Pruebas)"
echo "   - Firefox / Chromium / Epiphany: Set de navegadores para pruebas de rendimiento."
echo "   - LibreOffice: Suite completa para oficina."
echo "   - VLC Media Player: Reproductor multimedia universal."
echo "   - GIMP: Editor avanzado de imagenes."
echo -n '¿Instalar este bloque de herramientas básicas? (s/n): '
read -r INSTALAR_CORE

if [[ "$INSTALAR_CORE" =~ ^[Ss]$ ]]; then
  echo "📦 Inyectando herramientas nativas base..."
  sudo apt update
  sudo apt install -y firefox-esr chromium epiphany-browser libreoffice vlc gimp

  echo "🎨 Enlazando navegadores en el menú de Openbox..."
  
  # Usamos comillas simples estrictas para que Bash no intente procesar el XML ni los escapes
  sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="Epiphany Web Browser"><action name="Execute"><execute>epiphany<\/execute><\/action><\/item>' ~/.config/openbox/menu.xml
  sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="Chromium Web Browser"><action name="Execute"><execute>chromium<\/execute><\/action><\/item>' ~/.config/openbox/menu.xml
  sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="Firefox Web Browser"><action name="Execute"><execute>firefox-esr<\/execute><\/action><\/item>' ~/.config/openbox/menu.xml
  
  # Forzar la recarga de Openbox
  openbox --reconfigure
  echo "✅ ¡Instalación y menú actualizados con éxito!"
fi

# Reactivamos la expansión de historial al terminar el bloque
set -H

# =========================================================================
# 💻 BLOQUE 2: ENTORNO DE DESARROLLO Y APRENDIZAJE (NATIVOS)
# =========================================================================
echo ""
echo "👉 BLOQUE 2: Entorno de Programación y Estudio"
echo "   - VS Code: Editor técnico optimizado para el aprendizaje y desarrollo de código."
echo -n "¿Instalar el entorno de programación y desarrollo? (s/n): "
read -r INSTALAR_DEV

if [[ "$INSTALAR_DEV" =~ ^[Ss]$ ]]; then
  echo "📦 Instalando VS Code desde los repositorios configurados del sistema..."

  if sudo apt update && sudo apt install -y code; then

    # Configuración del menú de Openbox
    if dpkg -s code &> /dev/null; then
      echo "🎨 Enlazando VS Code en el menú de Openbox..."

      # Ajuste para entornos embebidos/root:
      # evita problemas con el sandbox cuando VS Code se ejecuta como root.
      if [ "$EUID" -eq 0 ] || [ "$USER" = "root" ]; then
        LAUNCH_CMD="code --no-sandbox --user-data-dir=/root/.config/Code"
      else
        LAUNCH_CMD="code"
      fi

      sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="VS Code"><action name="Execute"><execute>'"${LAUNCH_CMD}"'<\/execute><\/action><\/item>' \
        /ruta/a/tu/menu.xml

    else
      echo "❌ [ERROR] VS Code no quedó instalado correctamente."
    fi

  else
    echo "❌ [ERROR] No se pudo instalar VS Code desde los repositorios configurados."
  fi
fi

# =========================================================================
# 📄 BLOQUE 3: GESTIÓN Y SEGURIDAD DOCUMENTAL (SOCIODIGITAL)
# =========================================================================
echo ""
echo "👉 BLOQUE 3: Gestión de Documentos y Firma Digital"
echo "   - Atril PDF: Visor ligero y veloz de documentos digitales."
echo "   - Xournal++: Herramienta de anotación que permite la firma manuscrita directa sobre PDFs."
echo "   - AutoFirma: Aplicación para la firma electrónica legal de documentos ante sedes administrativas."
echo -n "¿Instalar herramientas de Firma y Documentos PDF? (s/n): "
read -r INSTALAR_CIVIL
if [[ "$INSTALAR_CIVIL" =~ ^[Ss]$ ]]; then
  echo "📦 Desplegando herramientas criptográficas y de lectura ligera..."
  sudo apt install -y atril xournalpp
  
  echo "🎨 Enlazando Visores y Editores PDF en Openbox..."
  sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="Atril PDF Viewer"><action name="Execute"><execute>atril<\/execute><\/action><\/item>\n    <item label="Xournal++ (Firma Digital)"><action name="Execute"><execute>xournalpp<\/execute><\/action><\/item>' "$MENU_OPENBOX"

  echo "📦 Instalando entorno de ejecución Java y herramientas criptográficas..."
  sudo apt install -y default-jre libnss3-tools


  if [ -f "$DIR_REAL_INSTALADOR/dependencias_offline/autofirma.deb" ]; then
    sudo dpkg -i "$DIR_REAL_INSTALADOR/dependencias_offline/autofirma.deb"
    sudo apt install -y -f
    
    echo "🎨 Enlazando AutoFirma en el menú de Openbox..."
    sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="AutoFirma (Trámites Civiles)"><action name="Execute"><execute>autofirma<\/execute><\/action><\/item>' "$MENU_OPENBOX"
  else
    echo "⚠️ [ALERTA] Instalador offline de AutoFirma no encontrado."
  fi
fi

# =========================================================================
# ✉️ BLOQUE 4: GESTIÓN DE CORREO Y COMUNICACIÓN (NATIVO OFFLINE)
# =========================================================================
echo ""
echo "👉 BLOQUE 4: Correo Electrónico Profesional"
echo "   - Mailspring: Cliente de correo moderno y eficiente con bandeja de entrada unificada."
echo -n "¿Instalar el gestor de correo Mailspring (ARM64)? (s/n): "
read -r INSTALAR_MAIL
if [[ "$INSTALAR_MAIL" =~ ^[Ss]$ ]]; then
  echo "📦 Instalando motor de comunicación Mailspring..."
  if [ -f "$DIR_REAL_INSTALADOR/dependencias_offline/mailspring-arm64.deb" ]; then
    sudo dpkg -i "$DIR_REAL_INSTALADOR/dependencias_offline/mailspring-arm64.deb"
    sudo apt install -y -f
    
    echo "🎨 Enlazando Mailspring en Openbox..."
    sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="Mailspring Email"><action name="Execute"><execute>mailspring<\/execute><\/action><\/item>' "$MENU_OPENBOX"
  else
    echo "⚠️ [ALERTA] No se encontró el instalador offline de Mailspring."
  fi
fi

# =========================================================================
# 🚀 BLOQUE 5: CAPA DE CONECTIVIDAD, MULTIMEDIA AVANZADA Y SOPORTE
# =========================================================================
echo ""
echo "👉 BLOQUE 5: Conectividad y Entretenimiento"
echo "   - LocalSend: Transferencia directa de archivos entre dispositivos locales mediante red Wi-Fi."
echo "   - NoMachine: Servidor de escritorio remoto de alto rendimiento para control o asistencia técnica."
echo "   - Harmonoid: Reproductor local de música optimizado, ágil y con descarga automatizada de letras."
echo "   - WebApp de Spotify: Lanzador web integrado para la reproducción de música en streaming."
echo -n "¿Instalar este bloque de conectividad, música y soporte remoto? (s/n): "
read -r INSTALAR_FLATPAK
if [[ "$INSTALAR_FLATPAK" =~ ^[Ss]$ ]]; then
  echo "📦 Configurando subsistema Flatpak y herramientas de conectividad..."
  sudo apt install -y flatpak mpv libmpv-dev
  
  flatpak remote-add --if-not-exists flathub https://flathub.org 2>/dev/null
  flatpak install flathub org.localsend.localsend_app -y
  
  echo "🎨 Enlazando LocalSend en Openbox..."
  sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="LocalSend (Wi-Fi Transfer)"><action name="Execute"><execute>flatpak run org.localsend.localsend_app<\/execute><\/action><\/item>' "$MENU_OPENBOX"
  
  # Inyección de NoMachine nativo (desde dependencias locales)
  if [ -f "$DIR_REAL_INSTALADOR/dependencias_offline/nomachine-arm64.deb" ]; then
    sudo dpkg -i "$DIR_REAL_INSTALADOR/dependencias_offline/nomachine-arm64.deb"
    
    echo "🎨 Enlazando NoMachine en Openbox..."
    sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="NoMachine Remote Desktop"><action name="Execute"><execute>\/usr\/NX\/bin\/nxplayer<\/execute><\/action><\/item>' "$MENU_OPENBOX"
  fi

  # Inyección inteligente de Spotify WebApp (corre sobre el navegador nativo)
  echo "🎨 Enlazando WebApp de Spotify en Openbox..."
  sed -i '/<!-- INYECCION_AUTOMATICA -->/a \    <item label="Spotify Web"><action name="Execute"><execute>chromium --app=https:\/\/://spotify.com<\/execute><\/action><\/item>' "$MENU_OPENBOX"
fi

# === CORRECCIÓN DE ETIQUETA EN EL MENÚ DINÁMICO (SECUENCIAL) ===

# 1. Modificar el archivo del sistema para que obamenu lea "Epiphany Web" en vez de "Web"
if [ -f "/usr/share/applications/org.gnome.Epiphany.desktop" ]; then
    # Cambiamos el nombre genérico por el nombre real de la aplicación
    sed -i 's/^GenericName=.*/GenericName=Epiphany Web/' /usr/share/applications/org.gnome.Epiphany.desktop 2>/dev/null
    sed -i 's/^Name=.*/Name=Epiphany Web/' /usr/share/applications/org.gnome.Epiphany.desktop 2>/dev/null
    
    # Forzar al sistema a actualizar la base de datos de escritorio con el nuevo nombre
    update-desktop-database /usr/share/applications 2>/dev/null
fi

# 2. Forzar la reconfiguración gráfica en tu monitor por memoria (tu comando exitoso)
if pgrep -x "openbox" > /dev/null; then
    : "${DISPLAY:=:0}"
    export DISPLAY
    PID_OPENBOX=$(pgrep -x "openbox" | head -n 1)
    if [ -n "$PID_OPENBOX" ] && [ -d "/proc/$PID_OPENBOX" ]; then
        XAUTH_PROCESO=$(cat /proc/"$PID_OPENBOX"/environ 2>/dev/null | tr '\0' '\n' | grep '^XAUTHORITY=' | cut -d= -f2-)
        [ -n "$XAUTH_PROCESO" ] && export XAUTHORITY="$XAUTH_PROCESO"
    fi
    openbox --reconfigure 2>/dev/null
fi

# =========================================================================
# 🧹 HIGIENE FINAL DEL SISTEMA (RECUPERACIÓN EXTRA EN LA MICROSD)
# =========================================================================
echo ""
echo "🧹 Ejecutando asepsia final de paquetes y liberando caché..."
sudo apt autoremove -y
sudo apt clean

# Notificar a Openbox en caliente para que recargue el menú modificado sin reiniciar la sesión
openbox --reconfigure 2>/dev/null

echo "-------------------------------------------------------------------------"
echo "✅ [FASE 3 COMPLETADA] ¡Suite modular configurada y menú Openbox actualizado!"
echo "-------------------------------------------------------------------------"
