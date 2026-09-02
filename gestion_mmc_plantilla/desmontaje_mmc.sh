#!/bin/bash
echo "[+] Desmontando de forma segura la carpeta armbian_mmc..."
sudo umount /home/daniel/compartida/armbian_mmc

echo "[+] Destruyendo el lazo logico del dispositivo loop0..."
sudo losetup -d /dev/loop0

echo "[+] Verificando estado final de los canales virtuales..."
sudo losetup -a

echo "[V] EXITO: Hardware eMMC liberado y limpio para un apagado seguro."
