#!/usr/bin/env bash
# Barrido secuencial de GPIOs en Orange Pi Zero 3W (Allwinner A733 / sun60iw2)
# Banco PD = puerto 3 -> base 3 * 32 = 96 (rango 96..127). PD23 = 119, PD5 = 101.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Ejecuta como root: sudo bash $0"
    exit 1
fi

echo "=== Pines ocupados actualmente en /sys/kernel/debug/gpio ==="
grep -E "gpio-|sunxi" /sys/kernel/debug/gpio || true
echo ""

CANDIDATES=(96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127)

for gpio in "${CANDIDATES[@]}"; do
    if grep -qE "gpio-${gpio}\b|\(${gpio}\)" /sys/kernel/debug/gpio; then
        echo "[SKIP] gpio-${gpio} ya está reclamado por el kernel."
        continue
    fi

    echo "[TEST] Probando gpio-${gpio} en HIGH (3s)..."
    if echo "${gpio}" > /sys/class/gpio/export 2>/dev/null; then
        echo "out" > "/sys/class/gpio/gpio${gpio}/direction"
        echo 1 > "/sys/class/gpio/gpio${gpio}/value"
        sleep 3

        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
        if lspci 2>/dev/null | grep -qE "01:00\.0|Non-Volatile|PCI"; then
            echo ">>> [HALLAZGO] Dispositivo PCIe detectado con gpio-${gpio} <<<"
            lspci -nn
            break
        fi

        echo 0 > "/sys/class/gpio/gpio${gpio}/value"
        echo "${gpio}" > /sys/class/gpio/unexport 2>/dev/null || true
    else
        echo "[BUSY] No se pudo exportar gpio-${gpio}."
    fi
done
