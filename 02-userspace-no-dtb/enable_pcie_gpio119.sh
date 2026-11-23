#!/usr/bin/env bash
# Activa PD23 (gpio-119) en espacio de usuario sin modificar el DTB/DTBO
set -euo pipefail

PCIE_GPIO=119

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta como root: sudo bash $0"
    exit 1
fi

if [[ ! -d "/sys/class/gpio/gpio${PCIE_GPIO}" ]]; then
    echo "${PCIE_GPIO}" > /sys/class/gpio/export
fi

echo "out" > "/sys/class/gpio/gpio${PCIE_GPIO}/direction"
echo 1 > "/sys/class/gpio/gpio${PCIE_GPIO}/value"
sleep 0.5

echo 1 > /sys/bus/pci/rescan
sleep 0.5

lspci -vv -s 01:00.0 2>/dev/null | grep -E "01:00\.0|LnkCap:|LnkSta:" || lspci
