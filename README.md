Guía Didáctica de Hardware y Linux Embebido

Orange Pi Zero 3W: Habilitación de PCIe Gen3 (PD23 / gpio-119)
De la prueba secuencial de GPIOs y el script sin DTB hasta el Device Tree Overlay en DietPi (kernel 6.6.98-vendor-sun60iw2) con adaptador Waveshare de Raspberry Pi 5

1. El Punto de Partida y el Hardware Utilizado
La historia comienza con una Orange Pi Zero 3W (SoC Allwinner A733 / sun60iw2) ejecutando DietPi con el kernel 6.6.98-vendor-sun60iw2. Aunque la placa incorpora un conector FPC de 16 pines (paso de 0.5 mm), al conectar un adaptador M.2 externo —el Waveshare PCIe TO M.2 Board Rev2.0 diseñado para Raspberry Pi 5, que era el adaptador disponible en el mercado local— el adaptador no recibía energía por defecto y el bus PCIe no mostraba dispositivos.

Para conectar ambas placas se empleó la cinta plana FPC de impedancia controlada PCIe-Cable-50mm (16 pines, 0.5 mm). El cable USB-C conectado a la Orange Pi Zero 3W se utiliza exclusivamente para alimentación de la placa, mientras que las señales del bus PCIe viajan por la cinta plana de 16 pines.

Componente	Detalle del Montaje
Placa base (SBC)	Orange Pi Zero 3W — SoC Allwinner A733 (sun60i-a733 / sun60iw2)
Sistema y kernel	DietPi (aarch64) con kernel 6.6.98-vendor-sun60iw2
Adaptador PCIe externo	Waveshare PCIe TO M.2 Board Rev2.0 (formato Raspberry Pi 5, con conector auxiliar 5 V / GND)
Enlace físico PCIe	Cinta FPC de 16 pines (0.5 mm), PCIe-Cable-50mm
Pines clave hallados	PD23 (gpio-119) para alimentación PCIe y PD5 (gpio-101) para ventilador
2. Por Qué el Conector de la Zero 3W Es Compatible con Raspberry Pi 5
El conector FPC de 16 pines (0.5 mm) de la Orange Pi Zero 3W comparte compatibilidad física y eléctrica con cintas y adaptadores pensados para Raspberry Pi 5, lo que permitió usar el adaptador Waveshare sin modificar su diseño:

Pares diferenciales y reloj PCIe (esenciales): Las líneas de transmisión (PETn/PETp), recepción (PERn/PERp) y reloj de referencia (REFCLKn/REFCLKp) son señales diferenciales estándar de PCI Express. Al negociar el enlace con el controlador del Allwinner A733, transportan el tráfico PCIe Gen3 x1 (8.0 GT/s) siempre que la cinta FPC mantenga impedancia controlada.
Orange Pi Zero 3W — PCIe Gen3 (PD23 / gpio-119)
Page 1 of 5
Tierra común y riel de alimentación (esenciales): Compartir masa (GND) estabiliza la referencia de señal, y habilitar PD23 (gpio-119) energiza el regulador del bus PCIe. Si se conecta un dispositivo M.2 o acelerador de IA con mayor consumo, conviene reforzar la alimentación de 5 V / GND del adaptador.
Pines auxiliares o específicos de Raspberry Pi 5 (no causan problema): Las señales secundarias orientadas al ecosistema HAT+ de Raspberry Pi 5 no son requeridas para que el Allwinner A733 enumere el bus PCIe y no provocan conflictos si se respeta la orientación correcta de la cinta de 16 pines (0.5 mm).
3. Paso 1: Búsqueda Secuencial de Carriles GPIO
En el controlador sunxi-pinctrl del SoC Allwinner A733 (sun60iw2), cada banco de 32 líneas se calcula de forma lineal:

Fórmula de numeración GPIO en Linux: GPIOLinux = (Índice de Banco × 32) + Número de Pin
Banco PD (índice 3): rango 96..127  |  PD23 = (3 × 32) + 23 = 119  |  PD5 = (3 × 32) + 5 = 101
Primero se inspeccionó /sys/kernel/debug/gpio para excluir los pines ya reclamados por subsistemas activos (almacenamiento SD/MMC, Wi-Fi/BT SDIO, consola serial y USB). Luego se ejecutó un script de barrido secuencial sobre los pines libres del banco PD, activando cada candidato en salida alta (1) por 3 segundos y reescaneando el bus PCIe para observar qué pin encendía el adaptador Waveshare.

Orange Pi Zero 3W — PCIe Gen3 (PD23 / gpio-119)
Page 2 of 5
#!/usr/bin/env bash
# Paso 1: Barrido secuencial de GPIOs en el banco PD (96..127)
set -euo pipefail

CANDIDATES=(96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127)

for gpio in "${CANDIDATES[@]}"; do
    if grep -qE "gpio-${gpio}\b|\(${gpio}\)" /sys/kernel/debug/gpio; then
        echo "[SKIP] gpio-${gpio} ya está en uso."
        continue
    fi
    echo "[TEST] Probando gpio-${gpio} en HIGH..."
    if echo "${gpio}" > /sys/class/gpio/export 2>/dev/null; then
        echo "out" > "/sys/class/gpio/gpio${gpio}/direction"
        echo 1 > "/sys/class/gpio/gpio${gpio}/value"
        sleep 3
        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
        if lspci 2>/dev/null | grep -qE "01:00\.0|Non-Volatile|PCI"; then
            echo ">>> [HALLAZGO] gpio-${gpio} activó el bus PCIe <<<"
            lspci -nn
            break
        fi
        echo 0 > "/sys/class/gpio/gpio${gpio}/value"
        echo "${gpio}" > /sys/class/gpio/unexport 2>/dev/null || true
    fi
done
El barrido reveló que gpio-119 (PD23) encendía el regulador del puerto PCIe y permitía detectar el dispositivo en el bus, mientras que gpio-101 (PD5) correspondía al control del ventilador.

4. Paso 2: Solución Como Servicio Sin Tocar el DTB
Antes de modificar el Device Tree, se validó el funcionamiento dejando intacto el DTB original de DietPi mediante un script en espacio de usuario configurado como servicio de arranque. El script exporta gpio-119, lo fija como salida en nivel alto (1) y ordena al kernel reescanear el bus PCIe.

Orange Pi Zero 3W — PCIe Gen3 (PD23 / gpio-119)
Page 3 of 5
#!/usr/bin/env bash
# Paso 2: Activa PD23 (gpio-119) y reescanea PCIe sin modificar el DTB
set -euo pipefail

PCIE_GPIO=119

if [[ ! -d "/sys/class/gpio/gpio${PCIE_GPIO}" ]]; then
    echo "${PCIE_GPIO}" > /sys/class/gpio/export
fi

echo "out" > "/sys/class/gpio/gpio${PCIE_GPIO}/direction"
echo 1 > "/sys/class/gpio/gpio${PCIE_GPIO}/value"
sleep 0.5

echo 1 > /sys/bus/pci/rescan
sleep 0.5

lspci -vv -s 01:00.0 2>/dev/null | grep -E "01:00\.0|LnkCap:|LnkSta:" || lspci
[Unit]
Description=Enable PCIe power via PD23 (gpio-119) on Orange Pi Zero 3W
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/enable_pcie_gpio119.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
5. Paso 3: El Salto Definitivo al Device Tree Overlay (.dtbo)
Activar el pin en espacio de usuario ocurre después de que el kernel ya inició sus primeras fases. Para que la alimentación del puerto PCIe (PD23 / gpio-119) esté presente desde el inicio del kernel, se trasladó el regulador a un Device Tree Overlay (zero3w-opt.dts compilado a zero3w-opt.dtbo) y se habilitó en /boot/dietpiEnv.txt.

Orange Pi Zero 3W — PCIe Gen3 (PD23 / gpio-119)
Page 4 of 5
reg_vcc3v3_pcie: vcc3v3-pcie {
    compatible = "regulator-fixed";
    regulator-name = "vcc3v3-pcie";
    regulator-min-microvolt = <3300000>;
    regulator-max-microvolt = <3300000>;
    gpio = <&pio 3 23 0>; /* PD23 = (3 * 32) + 23 = gpio-119, ACTIVE_HIGH */
    enable-active-high;
    regulator-boot-on;
    regulator-always-on;
};
mkdir -p /boot/overlay-user
dtc -@ -I dts -O dtb -o /boot/overlay-user/zero3w-opt.dtbo /boot/overlay-user/zero3w-opt.dts
grep -q '^user_overlays=' /boot/dietpiEnv.txt \
  && sed -i 's/^user_overlays=.*/user_overlays=zero3w-opt/' /boot/dietpiEnv.txt \
  || echo 'user_overlays=zero3w-opt' >> /boot/dietpiEnv.txt
6. Verificación y Resultados Obtenidos
Con la configuración aplicada sobre DietPi (kernel 6.6.98-vendor-sun60iw2), el enlace quedó operativo en PCIe Gen3 x1 (8.0 GT/s) con rendimiento sostenido cercano a 661–663 MiB/s (acotado por el bus interno NSI del Allwinner A733) y temperaturas estables alrededor de 41 °C durante horas de operación continua.

#!/usr/bin/env bash
set -euo pipefail

uname -r
grep -E "119|101" /sys/kernel/debug/gpio || true
lspci -vv 2>/dev/null | grep -E "PCI bridge|NVM Express|LnkCap:|LnkSta:" || lspci || true
Resumen del recorrido: (1) Identificar pines libres en el banco PD del Allwinner A733 mediante barrido secuencial; (2) validar con PD23 (gpio-119) y un servicio sin modificar el DTB; (3) consolidar en un Device Tree Overlay (.dtbo) para encendido temprano y estable del enlace PCIe.
