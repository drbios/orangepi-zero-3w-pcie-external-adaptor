# Orange Pi Zero 3W (`sun60i-a733`) — PCIe Gen3 External Adapter (`PD23` / `gpio-119`)

Guía y scripts reproducibles para habilitar **PCIe Gen3 x1** en **Orange Pi Zero 3W** (`Allwinner A733` / `sun60iw2`) ejecutando **DietPi** con el kernel **`6.6.98-vendor-sun60iw2`** y el adaptador externo **Waveshare PCIe TO M.2 Board Rev2.0** (diseñado para **Raspberry Pi 5**) conectado mediante cinta plana FPC de **16 pines (`0.5 mm`)**.

## Etapas documentadas
1. **`01-gpio-scan/scan_pcie_gpio.sh`:** Metodología de búsqueda secuencial sobre el banco `PD` (`96..127`, donde `GPIO = Puerto * 32 + Pin`), excluyendo pines ya usados en `/sys/kernel/debug/gpio` hasta ubicar **`PD23` (`gpio-119`)** para la alimentación PCIe y **`PD5` (`gpio-101`)** para el ventilador.
2. **`02-userspace-no-dtb/enable_pcie_gpio119.sh`:** Solución inicial sin modificar DTB, exportando `gpio-119` en alto y ejecutando `/sys/bus/pci/rescan`.
3. **`03-devicetree-final/` y `scripts/zero3w-master-setup.sh`:** Integración nativa en *Device Tree Overlay* (`.dtbo`) con regulador `vcc3v3-pcie` en `PD23` (`gpio-119`), control térmico por kernel en `PD5` (`gpio-101`) y optimización *headless*.

## Notas de hardware
- El puerto USB-C alimenta la placa; los datos PCIe viajan por la cinta FPC de 16 pines (`PCIe-Cable-50mm` de impedancia controlada).
- Rendimiento medido por PCIe Gen3 x1: `~661–663 MiB/s` sostenidos (limitado en el bus interno NSI del Allwinner A733), estable por más de 8 horas a `41 °C`.
