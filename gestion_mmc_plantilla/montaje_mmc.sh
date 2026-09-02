#!/bin/bash
echo "[+] Limpiando loops viejos en el sistema..."
sudo umount /home/daniel/compartida 2>/dev/null
sudo losetup -d /dev/loop0 2>/dev/null

echo "[+] Creando el punto de acceso seguro armbian_mmc..."
mkdir -p /home/daniel/compartida/armbian_mmc

echo "[+] Enlazando loop0 al offset del silicio crudo (4561305600)..."
sudo losetup -o 4561305600 /dev/loop0 /dev/mmcblk1

echo "[+] Montando particion eMMC fisica en EXT4..."
sudo mount -t ext4 -o rw /dev/loop0 /home/daniel/compartida/armbian_mmc

echo "[+] Asignando permisos de propietario a tu usuario daniel..."
sudo chown -R daniel:daniel /home/daniel/compartida/armbian_mmc

echo "[V] EXITO: Almacenamiento armbian_mmc listo para produccion!"
ls -la /home/daniel/compartida/armbian_mmc
