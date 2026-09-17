#!/bin/bash
echo "[+] Iniciando reconocimiento automatico de la eMMC..."
sudo umount /mnt/prueba_offset 2>/dev/null
sudo losetup -d /dev/loop0 2>/dev/null
mkdir -p /mnt/prueba_offset

# 1. Almacenamos los offsets validos filtrados en una variable interna de Bash
# Usamos el super filtro que tu calibraste esta noche
OFFSETS=$(sudo binwalk --include=filesystem /dev/mmcblk1 | grep -v -E "copyright|string|invalid|gzip|zip|ESP|intel" | awk '{print $1}')

echo "[+] Analizando candidatos encontrados en el silicio..."
echo "--------------------------------------------------------"

# 2. El bucle magico que recorre cada numero decimal encontrado
for offset in $OFFSETS; do
    # Validamos que el valor sea puramente numerico antes de intentar el lazo
    if [[ $offset =~ ^[0-9]+$ ]]; then
        echo "[*] Probando Offset Decimal: $offset"
        
        # Intentamos enlazar y montar de forma silenciosa
        sudo losetup -o $offset /dev/loop0 /dev/mmcblk1 2>/dev/null
        sudo mount -t ext4 -o rw,ro /dev/loop0 /mnt/prueba_offset 2>/dev/null
        
        # 3. Si el montaje fue exitoso, imprimimos los directorios reales que tiene adentro
        if [ $? -eq 0 ]; then
            echo "    [V] MONTAJE EXITOSO! Directorios encontrados:"
            echo "    ----------------------------------------"
            ls /mnt/prueba_offset | sed 's/^/    |-- /'
            echo "    ----------------------------------------"
            
            # Limpiamos para la siguiente iteracion
            sudo umount /mnt/prueba_offset
            sudo losetup -d /dev/loop0
        else
            echo "    [-] Bloque no montable de forma directa (Saltando...)"
            sudo losetup -d /dev/loop0 2>/dev/null
        fi
        echo ""
    fi
done

echo "[+] Escaneo dinamico finalizado con exito."
