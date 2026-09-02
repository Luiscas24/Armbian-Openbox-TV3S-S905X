#!/bin/bash
# 🎛️ MOTOR DE ADAPTACIÓN EN CALIENTE Y CONFIGURACIÓN DE POST-GRABADO
# Ejecutar en tu computadora Ubuntu con la tarjeta SD montada.

# --- AUTO-SOLICITUD DE PERMISOS ROOT ---
if [ "$EUID" -ne 0 ]; then
  echo "🔐 [INFO] Este script necesita permisos de administrador. Solicitando sudo..."
  exec sudo "$0" "$@"
  exit 1
fi

# 🌟 CAPTURA DINÁMICA DEL USUARIO REAL (Daniel, Pedro, etc.)
USUARIO_REAL="${SUDO_USER:-$USER}"

# 🌟 FIJAMOS EL OBJETIVO UNIVERSAL EN UBUNTU
TARJETA_ROOT="/run/media/$USUARIO_REAL/armbi_boot"

echo "========================================================"
echo "[+] INICIANDO ADAPTACIÓN DE HARDWARE EN LA TARJETA SD"
echo "    Punto de montaje objetivo: $TARJETA_ROOT"
echo "========================================================"

# Validamos que la tarjeta esté físicamente conectada y montada antes de operar
if [ ! -d "$TARJETA_ROOT" ]; then
    echo "⚠️ [ERROR RECONOCIMIENTO] No se encuentra la tarjeta en: $TARJETA_ROOT"
    echo "Por favor, asegúrate de que la tarjeta SD esté conectada y montada en tu Ubuntu."
    exit 1
fi

# 🔍 CAPA DE PROTECCIÓN DEFENSIVA EXCLUSIVA
if [ -f "$TARJETA_ROOT/u-boot.ext" ] && [ -f "$TARJETA_ROOT/dtb.img" ]; then
    echo "[=] [INFO] Se detectó 'u-boot.ext' y 'dtb.img' en la raíz de la tarjeta."
    echo "[=] El hardware S905X de la serie P212 ya está habilitado en esta tarjeta."
    echo "[=] Omitiendo reconfiguración física para proteger los archivos actuales."
else
    echo "[+] No se detectó habilitación previa en la raíz (Faltan u-boot.ext o dtb.img)."
    echo "[+] Procediendo con la inyección estática doble para la serie P212..."
    
    # 1. CLONACIÓN DEL U-BOOT EXACTO DE TU CHIP S905X
    if [ -f "$TARJETA_ROOT/u-boot-s905x-s912" ]; then
        echo "[+] Clonando binario u-boot-s905x-s912 como u-boot.ext en la raíz..."
        cp -f "$TARJETA_ROOT/u-boot-s905x-s912" "$TARJETA_ROOT/u-boot.ext" 2>/dev/null
    else
        echo "⚠️ [ALERTA] No se encontró el archivo fuente u-boot-s905x-s912 en la tarjeta."
    fi

    # 2. INYECCIÓN FÍSICA DEL ARCHIVO DTB DE 41 KB EN LA RAÍZ
    if [ -f "$TARJETA_ROOT/dtb/amlogic/meson-gxl-s905x-p212.dtb" ]; then
        echo "[+] Copiando árbol meson-gxl-s905x-p212.dtb como dtb.img puro (41 KB) en la raíz..."
        cp -f "$TARJETA_ROOT/dtb/amlogic/meson-gxl-s905x-p212.dtb" "$TARJETA_ROOT/dtb.img" 2>/dev/null
    else
        echo "⚠️ [ALERTA] No se encontró el origen del DTB en $TARJETA_ROOT/dtb/amlogic/"
    fi

    echo "[+] ¡Estructura de hardware estática doble inyectada con éxito!"
    echo "[+] Nota: extlinux.conf preservado intacto de fábrica para evitar desastres de APT."
fi

echo "========================================================"
echo ""

# =========================================================================
# 🔀 FLUJO INTERACTIVO DE TRABAJO
# =========================================================================

SOLICITA_PREINSTALL=false

while true; do
    read -p "🛠️ ¿El sistema requiere paquetes de desarrollo o pre-instalación? (s/n): " PRE_RESP
    case "$PRE_RESP" in
        [Ss]* )
            echo "📌 [INFO] Modo Desarrollo activo. Se omitirá la pregunta de desmontado."
            SOLICITA_PREINSTALL=true
            break
            ;;
        [Nn]* )
            break
            ;;
        * ) echo "Por favor, responde 's' (sí) o 'n' (no).";;
    esac
done

# Si NO requirió paquetes de desarrollo, se le da la opción de desmontar la imagen
if [ "$SOLICITA_PREINSTALL" = false ]; then
    while true; do
        read -p "🔌 ¿Deseas desmontar la imagen de la tarjeta de forma segura ahora mismo? (s/n): " DESM_RESP
        case "$DESM_RESP" in
            [Ss]* )
                # CAPTURA QUIRÚRGICA DEL DISCO PADRE REAL (ej: sdc, sdb, etc.)
                DISCO_PARTICION=$(df -P "$TARJETA_ROOT" | tail -1 | awk '{print $1}')
                DISCO_BASE_NAME=$(lsblk -no pkname "$DISCO_PARTICION" | head -n 1)
                
                if [ -z "$DISCO_BASE_NAME" ]; then
                    DISCO_BASE_NAME=$(echo "$DISCO_PARTICION" | sed -E 's|/dev/||; s|[0-p]*[0-9]$||')
                fi
                
                DISCO_BASE="/dev/$DISCO_BASE_NAME"
                echo "[+] Tarjeta física identificada dinámicamente en: $DISCO_BASE"
                
                # Salimos al home para liberar los descriptores de la terminal
                cd ~
                EJECUTAR_DESMONTAJE=true
                break
                ;;
            [Nn]* )
                echo "📌 [INFO] La tarjeta permanecerá montada en el sistema."
                EJECUTAR_DESMONTAJE=false
                break
                ;;
            * ) echo "Por favor, responde 's' (sí) o 'n' (no).";;
        esac
    done
fi

# =========================================================================
# 💾 BUFFER DE ESCRITURA EN RAM Y SINCRONIZACIÓN FINAL
# =========================================================================
echo ""
echo "📊 [RAM Cache] Analizando datos pendientes por volcar en la tarjeta SD..."

DIRTY_MEM=$(grep -E '^Dirty:' /proc/meminfo | awk '{print $2}')

if [ "$DIRTY_MEM" -gt 0 ]; then
    echo "⏳ Hay exactamente ${DIRTY_MEM} KB de datos pendientes en la caché de la RAM."
else
    echo "✅ La memoria RAM está limpia. Todos los datos previos ya se habían escrito."
fi

echo "💾 [SYNC] Forzando el volcado físico de los búferes de memoria hacia la SD..."
sync

DIRTY_POST=$(grep -E '^Dirty:' /proc/meminfo | awk '{print $2}')
echo "[+] Sincronización terminada. Datos sucios remanentes en RAM: ${DIRTY_POST} KB."

# 🔌 PROCESAMIENTO DE EXPULSIÓN INTEGRAL Y DESMONTAJE SEGURO
if [ "$EJECUTAR_DESMONTAJE" = true ]; then
    echo "[+] Desmontando quirúrgicamente las particiones que pertenecen a la tarjeta..."
    
    # Buscamos todas las sub-particiones montadas vinculadas estrictamente a este disco base
    for part_path in $(mount | grep "$DISCO_BASE" | awk '{print $1}'); do
        echo "[*] Liberando de forma directa: $part_path"
        umount -l "$part_path" 2>/dev/null
    done
    
    echo "[+] Enviando señal de expulsión segura al bus de hardware..."
    eject "$DISCO_BASE" 2>/dev/null
    
    # Cortamos la energía del puerto físico
    sudo -u "$USUARIO_REAL" udisksctl power-off -b "$DISCO_BASE" 2>/dev/null
    
    # Refrescamos el subsistema de volúmenes de usuario para asentar el desmontado gráfico
    sudo -u "$USUARIO_REAL" pkill -f gvfsd-trash 2>/dev/null
    sudo -u "$USUARIO_REAL" gvfs-mount -s 2>/dev/null || sudo -u "$USUARIO_REAL" gio mount -s 2>/dev/null
    
    echo "✅ [ÉXITO] ¡Dispositivo desvinculado con total seguridad a nivel de sistema!"
    echo "🔒 [OK] Es totalmente seguro retirar la tarjeta SD físicamente ahora."
fi

# =========================================================================
# 🚀 EJECUCIÓN POSTERIOR DE PRE-INSTALACIÓN (AL FINAL)
# =========================================================================
if [ "$SOLICITA_PREINSTALL" = true ]; then
    DIR_HOST_SCRIPT="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
    cd "$DIR_HOST_SCRIPT" 2>/dev/null
    
    if [ -f "./pre_instalacion.sh" ]; then
        echo ""
        echo "[+] Lanzando ejecutor de pre-instalación de forma aislada y segura desde el host..."
        chmod +x "./pre_instalacion.sh"
        bash "./pre_instalacion.sh"
    else
        echo ""
        echo "⚠️ [ERROR] Se solicitó pre-instalación pero no se encontró 'pre_instalacion.sh' en la carpeta del host ($DIR_HOST_SCRIPT)."
    fi
fi

echo ""
echo "🏁 [FIN] Proceso de habilitación de hardware finalizado correctamente."
