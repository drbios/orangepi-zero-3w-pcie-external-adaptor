# Informe Técnico: Habilitación PCIe Waveshare e Integración DTB en Orange Pi Zero 3W (`sun60i-a733`)

## 1. Contexto de hardware y sistema

- **Placa:** Orange Pi Zero 3W con SoC Allwinner **A733** (`sun60i-a733`).
- **Sistema operativo y kernel:** **DietPi** sobre kernel `6.6.98-vendor-sun60iw2`.
- **Objetivo:** Habilitar el adaptador PCIe externo **Waveshare** y la enumeración de unidad NVMe en la placa, pasando desde pruebas de control manual hasta una integración estable a nivel de *Device Tree* (DTB).

---

## 2. Compatibilidad de pines con adaptadores RPI

Los adaptadores y HATs de expansión diseñados para cabecera de 40 pines tipo Raspberry Pi comparten distribución física y rieles base en los pines expuestos, lo que permite acoplar mecánicamente el módulo en la cabecera de la placa. Sin embargo, el mapeo interno de GPIO, el controlador de pines (`pinctrl`) y los nodos del *Device Tree* corresponden al SoC Allwinner `sun60i-a733` y no al controlador de Raspberry Pi, por lo que la gestión del pin de habilitación (`PD23` / `gpio119`) debe resolverse en la capa del kernel/DTB de la Orange Pi Zero 3W.

---

## 3. Evolución: búsqueda de GPIO, hot-plug, servicio y DTB

| Etapa | Implementación | Propósito | Transición |
| :--- | :--- | :--- | :--- |
| **Búsqueda secuencial de GPIO** | Script de prueba sobre líneas GPIO | Localizar qué línea controla la habilitación del adaptador PCIe | Base para controlar el pin específico (`PD23` / `gpio119`) |
| **Activación en caliente (`hot-plug`)** | Script para energizar el adaptador y reescanear `/sys/bus/pci/rescan` | Detectar y enumerar el SSD conectado sin reiniciar todo el sistema | Se automatiza como servicio de arranque |
| **Servicio `systemd`** | Unidad previa de `userspace` (`zero3w-gpio119.service`) | Aplicar el estado del pin tras iniciar el sistema | Se deshabilita al delegar el riel al DTB |
| **Integración en DTB** | Overlay `/boot/overlay-user/zero3w-opt.dts` + `dietpiEnv.txt` | Declarar el riel como `regulator-fixed` en el árbol de dispositivos | Solución definitiva y reproducible |

---

## 4. Scripts de prueba en caliente y servicio `systemd`

### Script de activación y reescaneo PCIe (`hot-plug`)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Activa la enumeracion del bus PCIe tras energizar el adaptador y el SSD
if [ -e /sys/bus/pci/rescan ]; then
  echo 1 > /sys/bus/pci/rescan
fi

lspci -nn
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
```

### Transición desde servicio `systemd` hacia DTB

En la etapa previa de *userspace* se utilizaba un servicio (`zero3w-gpio119.service`) para manipular el pin. Al mover la definición del riel al *Device Tree* como regulador fijo (`regulator-fixed`), el servicio de `sysfs` se deshabilita para evitar conflictos o redundancias:

```bash
sudo systemctl disable zero3w-gpio119.service 2>/dev/null || true
```

---

## 5. Archivo overlay DTB (`zero3w-opt.dts`) e integración

El riel de alimentación PCIe (`PD23` / `gpio119`) se define como `regulator-fixed` en `/boot/overlay-user/zero3w-opt.dts`, junto con la deshabilitación de nodos no utilizados en el fragmento de optimización:

```dts
/dts-v1/;
/plugin/;

/ {
	fragment@0 {
		target-path = "/";
		__overlay__ {
			zero3w-pcie-en {
				compatible = "regulator-fixed";
				regulator-name = "zero3w-pcie-en";
				regulator-min-microvolt = <3300000>;
				regulator-max-microvolt = <3300000>;
				gpio = <&pio 3 23 0>; /* PD23 = gpio119, active high */
				enable-active-high;
				regulator-boot-on;
				regulator-always-on;
			};
		};
	};

	fragment@1 {
		target-path = "/soc@3000000/ufs@04520000";
		__overlay__ {
			status = "disabled";
		};
	};

	fragment@2 {
		target-path = "/soc@3000000/twi@251C000/touchscreen@14";
		__overlay__ {
			status = "disabled";
		};
	};

	fragment@3 {
		target-path = "/soc@3000000/i2s0_mach";
		__overlay__ {
			status = "disabled";
		};
	};
};
```

### Pasos para compilar, validar e integrar el overlay

1. **Compilar el `.dts` a `.dtbo`:**

   ```bash
   sudo mkdir -p /boot/overlay-user
   sudo dtc -@ -I dts -O dtb -o /boot/overlay-user/zero3w-opt.dtbo /boot/overlay-user/zero3w-opt.dts
   ```

2. **Validar offline con `fdtoverlay` contra el DTB base:**

   ```bash
   sudo fdtoverlay -i /boot/dtb/allwinner/sun60i-a733-orangepi-zero3w.dtb \
     -o /tmp/zero3w-merged-check.dtb \
     /boot/overlay-user/zero3w-opt.dtbo
   rm -f /tmp/zero3w-merged-check.dtb
   ```

3. **Registrar en `/boot/dietpiEnv.txt` y reiniciar:**

   ```bash
   sudo cp -a /boot/dietpiEnv.txt "/boot/dietpiEnv.txt.bak.$(date +%Y%m%d%H%M%S)"
   ```

   Asegura que `user_overlays=zero3w-opt` (o incluyendo overlays adicionales compatibles) esté configurado en `/boot/dietpiEnv.txt`, deshabilita `zero3w-gpio119.service` y reinicia con `sync && sudo reboot`.

---

## 6. Verificación tras reiniciar

```bash
lspci
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
dmesg -T | grep -iE "pcie|nvme|regulator|119|PD23"
```
