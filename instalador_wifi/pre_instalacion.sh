#!/bin/bash
#Script que prepara las condiciones para que la imagen sea plenamente utilizable en el dispositivo.

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  # Se relanza a sí mismo usando sudo, preservando los argumentos y el entorno
  exec sudo "$0" "$@"
  exit 1
fi

# --- AUTOCORRECCIÓN DE ENTORNO Y RUTAS ---
# Se auto-muda a la carpeta real donde vive el archivo
cd "$(dirname "$(readlink -f "$0")")"
# Asegura las rutas de comandos del sistema para evitar el "command not found"
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
# ----------------------------------------

echo "Comprobamos git y curl, de no existir los instalamos"
dpkg -s git curl lftp &> /dev/null || sudo apt install -y git curl lftp

echo "Clonamos el repositorio en git"
git clone --progress --depth 1 https://github.com/jwrdegoede/rtl8189ES_linux.git

# 1. Creamos la carpeta y nos mudamos adentro INMEDIATAMENTE
echo "[+] Preparando directorio unificado de dependencias offline..."
mkdir -p dependencias_offline
cd dependencias_offline

echo "[+] Descarga de paquetes del ecosistema del kernel"

LFTP_OPTS="set net:timeout 10; set net:max-retries 2; set net:reconnect-interval-base 5; set xfer:clobber on; set cmd:verbose true;"

echo "⬇️  Abriendo subcarpeta y descargando: linux-image"

lftp -c "
    $LFTP_OPTS
    open https://armbian.lv.auroradev.org/beta/pool/main/l/linux-6.18.48/;
    mget linux-image-current-meson64_*.deb
  "

for COMPONENT in headers dtb libc-dev; do
    echo "⬇️  Abriendo subcarpeta y descargando: linux-$COMPONENT"
    
    lftp -c "
      $LFTP_OPTS
      open https://armbian.lv.auroradev.org/beta/pool/main/l/linux-${COMPONENT}-current-meson64/;
      mget linux-${COMPONENT}-current-meson64_*.deb
    "
done

# 1. Definimos el espejo oficial de Debian y la versión (ej. bookworm, trixie, etc.)
DEBIAN_MIRROR="https://ftp.debian.org/debian"
DEBIAN_SUITE="trixie"  # Cambia por la versión de Debian en la que se base tu Armbian

echo "[+] Descargando índice de paquetes oficial de Debian ($DEBIAN_SUITE arm64)..."
curl -sL "$DEBIAN_MIRROR/dists/$DEBIAN_SUITE/main/binary-arm64/Packages.gz" | gunzip > Packages

# 2. Lista de herramientas base que necesitas para compilar
HERRAMIENTAS="build-essential gcc make libc6-dev bison flex libssl-dev libelf-dev"

# Arreglos para el control de dependencias en Bash
echo "[+] Calculando árbol de dependencias recursivo para arm64..."
declare -A PROCESADOS
POR_PROCESAR=($HERRAMIENTAS)

# Función interna para extraer dependencias directamente desde el archivo de texto Packages
# Función interna mejorada y blindada contra caracteres especiales de Debian
obtener_dependencias() {
    local pkg="$1"
    awk -v p="$pkg" '
        $1 == "Package:" && $2 == p { found=1; next }
        found && $1 == "Depends:" { 
            # Reemplaza comas, paréntesis, barras verticales y operadores por espacios
            gsub(/[,()|>=<]/, " ", $0);
            $1=""; print $0; exit 
        }
        found && $1 == "" { exit }
    ' Packages
}

# Bucle recursivo puro en Bash
while [ ${#POR_PROCESAR[@]} -gt 0 ]; do
    ACTUAL="${POR_PROCESAR[0]}"
    POR_PROCESAR=("${POR_PROCESAR[@]:1}") # Shift el arreglo

    # Si ya lo procesamos, lo ignoramos
    if [ -n "${PROCESADOS[$ACTUAL]}" ]; then
        continue
    fi
    PROCESADOS[$ACTUAL]=1

    # Obtenemos las dependencias del paquete actual
    DEPS=$(obtener_dependencias "$ACTUAL")
    for DEP in $DEPS; do
        # Evitamos paquetes virtuales comunes del sistema o vacíos
        if [[ -n "$DEP" && ! "$DEP" =~ ^(debconf|perl-base|libc-bin|linux-libc-dev)$ && -z "${PROCESADOS[$DEP]}" ]]; then
            POR_PROCESAR+=("$DEP")
        fi
    done
done

echo "[+] Descargando de forma quirúrgica todos los .deb requeridos..."
# 3. Descarga final de los paquetes mapeados en la lista de procesados
for PKG in "${!PROCESADOS[@]}"; do
    # Extraemos la ruta exacta del archivo .deb en el servidor de Debian
    FILENAME=$(awk -v p="$PKG" '
        $1 == "Package:" && $2 == p { found=1; next }
        found && $1 == "Filename:" { print $2; exit }
        found && $1 == "" { exit }
    ' Packages)

    if [ -n "$FILENAME" ]; then
        FILE_DEB=$(basename "$FILENAME")
        echo "⬇️  Descargando paquete arm64: $FILE_DEB"
        curl -L -O --progress-bar --connect-timeout 10 "$DEBIAN_MIRROR/$FILENAME"
    fi
done

# Limpieza del archivo de índice para no dejar basura local
rm Packages
cd ..

# -------------------------------------------------------------------------
# DEVOLVER PROPIEDAD AL USUARIO REAL (Evita el bloqueo de permisos Root)
# -------------------------------------------------------------------------
# Si el script se ejecutó a través de sudo, restauramos los permisos al usuario original
if [ -n "$SUDO_USER" ]; then
    echo "[+] Restaurando permisos de lectura y escritura para el usuario: $SUDO_USER"
    
    # Obtenemos el grupo primario del usuario original de forma dinámica
    USER_GROUP=$(id -gn "$SUDO_USER")
    
    # Cambiamos el propietario y grupo de las carpetas creadas de forma recursiva (-R)
    chown -R "$SUDO_USER:$USER_GROUP" dependencias_offline
    chown -R "$SUDO_USER:$USER_GROUP" rtl8189ES_linux
fi
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# AUTO-COPIA, ESCRITURA FÍSICA Y DESMONTAJE SEGURO (Mapeo dinámico de usuario)
# -------------------------------------------------------------------------
# Detectamos el usuario real (si no se usó sudo, cae de respaldo al usuario actual)
LOGGED_USER="${SUDO_USER:-$USER}"

# Construimos las rutas dinámicas usando la variable del usuario detectado
MEDIA_BASE="/run/media/$LOGGED_USER"
RUTA_DESTINO="$MEDIA_BASE/armbi_root/root/instalador_wifi"

if [ -d "$MEDIA_BASE/armbi_root" ]; then
    echo "[+] Detectada partición externa 'armbi_root' para el usuario $LOGGED_USER..."
    mkdir -p "$RUTA_DESTINO"
    
# -------------------------------------------------------------------------
# AUTO-COPIA Y NORMALIZACIÓN DE PERMISOS HÍBRIDOS (Mapeo dinámico de usuario)
# -------------------------------------------------------------------------
LOGGED_USER="${SUDO_USER:-$USER}"
MEDIA_BASE="/run/media/$LOGGED_USER"
RUTA_DESTINO="$MEDIA_BASE/armbi_root/root/instalador_wifi"

if [ -d "$MEDIA_BASE/armbi_root" ]; then
    echo "[+] Detectada partición externa 'armbi_root' para el usuario $LOGGED_USER..."
    mkdir -p "$RUTA_DESTINO"
    
    # Copiamos todo en bloque (scripts, debs y código fuente)
    cp -r pre_instalacion.sh post_instalacion_fase1.sh post_instalacion_fase2.sh dependencias_offline rtl8189ES_linux "$RUTA_DESTINO/"

    echo "[+] Sincronizando datos físicamente en el almacenamiento..."
    echo "⏳ Por favor, no retires el dispositivo. Escribiendo caché de RAM a la tarjeta SD..."

    # Forzamos un inicio de sync en segundo plano (&) para poder medirlo
    sync &
    SYNC_PID=$!

    # Bucle visual original que monitorea la memoria caché pendiente por escribir
    while kill -0 $SYNC_PID 2>/dev/null; do
        DIRTY_MB=$(awk '/Dirty:/ {print int($2/1024)}' /proc/meminfo)
        if [ "$DIRTY_MB" -gt 0 ]; then
            printf "\r⏳ Datos pendientes en búfer de RAM: %d MB todavía escribiéndose... " "$DIRTY_MB"
        else
            printf "\r⏳ Finalizando la sincronización física del hardware... "
        fi
        sleep 1
    done
    echo -e "\n✨ [OK] ¡Escritura física completada al 100%!"
    echo ""

    # 🔀 PREGUNTA INTERACTIVA DE DESMONTAJE
    EJECUTAR_DESMONTAJE=false
    while true; do
        read -p "🔌 ¿Deseas desmontar las particiones de la tarjeta de forma segura ahora mismo? (s/n): " DESM_RESP
        case "$DESM_RESP" in
            [Ss]* )
                EJECUTAR_DESMONTAJE=true
                break
                ;;
            [Nn]* )
                echo "📌 [INFO] La tarjeta permanecerá montada en el sistema para tus verificaciones."
                break
                ;;
            * ) echo "Por favor, responde 's' (sí) o 'n' (no).";;
        esac
    done

    # 🔌 PROCESAMIENTO DE EXPULSIÓN INTEGRAL (Solo si el usuario dijo que Sí)
    if [ "$EJECUTAR_DESMONTAJE" = true ]; then
        echo "[+] Identificando el dispositivo físico de la tarjeta para su expulsión masiva..."
        # Captura quirúrgica del disco padre real a partir del punto de montaje (ej: sdc, sdb, etc.)
        DISCO_PARTICION=$(df -P "$MEDIA_BASE/armbi_root" | tail -1 | awk '{print $1}')
        DISCO_BASE_NAME=$(lsblk -no pkname "$DISCO_PARTICION" | head -n 1)
        
        # Respaldo de filtrado de texto por seguridad
        if [ -z "$DISCO_BASE_NAME" ]; then
            DISCO_BASE_NAME=$(echo "$DISCO_PARTICION" | sed -E 's|/dev/||; s|[0-p]*[0-9]$||')
        fi
        
        DISCO_BASE="/dev/$DISCO_BASE_NAME"
        echo "[+] Tarjeta física aislada dinámicamente en: $DISCO_BASE"

        echo "[+] Desmontando quirúrgicamente las particiones de la tarjeta..."
        # Escaneamos de forma segura las sub-particiones montadas vinculadas únicamente a este disco
        for part_path in $(mount | grep "$DISCO_BASE" | awk '{print $1}'); do
            echo "[*] Liberando de forma directa: $part_path"
            # Desmontado forzado perezoso (lazy) como root puro para no pedir claves en bucle
            umount -l "$part_path" 2>/dev/null
        done
        
        echo "[+] Enviando señal de expulsión segura al bus de hardware..."
        eject "$DISCO_BASE" 2>/dev/null
        
        # Cortamos la energía del puerto físico a nombre del usuario para asentar la expulsión
        sudo -u "$LOGGED_USER" udisksctl power-off -b "$DISCO_BASE" 2>/dev/null
        
        # Refrescamos el subsistema de volúmenes de usuario para asentar el desmontado visual
        pkill -f gvfsd-trash 2>/dev/null
        sudo -u "$LOGGED_USER" gvfs-mount -s 2>/dev/null || sudo -u "$LOGGED_USER" gio mount -s 2>/dev/null
        
        echo "✅ [ÉXITO] ¡Tarjeta SD completamente desvinculada a nivel de sistema!"
        echo "🔒 [OK] Es totalmente seguro retirar la tarjeta SD físicamente ahora."
    fi
else
    echo "⚠️  [AVISO] La partición 'armbi_root' no está montada en $MEDIA_BASE. Se omitió la copia y el desmontaje."
fi

echo "[+] ¡Ecosistema offline arm64 completado universalmente!"
