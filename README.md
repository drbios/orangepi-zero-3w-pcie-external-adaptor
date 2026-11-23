# Orange Pi Zero 3W (`sun60i-a733`) — PCIe / NVMe & DietPi Optimization

Notas técnicas, overlays de *Device Tree* (DTB) y script de automatización para habilitar alimentación PCIe, control de ventilador, modo *headless* y rendimiento sostenido en la **Orange Pi Zero 3W** (SoC Allwinner `sun60i-a733`) ejecutando **DietPi**.

---

## Resumen de la adaptación

- **SoC y plataforma:** Orange Pi Zero 3W con procesador Allwinner **A733** (`sun60i-a733`), kernel vendor/BSP (por ejemplo `6.6.98-vendor-sun60iw2`) bajo **DietPi**.
- **Alimentación PCIe (`PD23` / `gpio119`):** Definida como regulador fijo (`regulator-fixed`) en el *Device Tree* mediante overlay en lugar de depender de scripts tardíos en *userspace*.
- **Ventilador / rail auxiliar (`PD5` / `gpio101`):** Configurado como regulador fijo en `zero3w-opt.dts`, deshabilitando `pwm-fan` cuando se usa control directo por rail/GPIO.
- **Compatibilidad Wi-Fi y almacenamiento:** Se conservan los nodos críticos de red inalámbrica y bus SDIO/MMC (`sdmmc@4022000`, `serdes@6c00000`), evitando conflictos al deshabilitar periféricos de video/audio en modo *headless*.
- **Rendimiento de almacenamiento:** En pruebas `fio` sobre partición `ext4` en `/mnt/nvme` (Samsung PM951 256 GB NVMe), se alcanzan lecturas/escrituras secuenciales del orden de **~650–663 MiB/s** en el enlace disponible.

---

## Estructura del repositorio

```text
.
├── README.md
├── zero3w-master-setup.sh
└── overlays/
    ├── zero3w-opt.dts
    └── zero3w-headless-safe.dts
Requisitos previos
Acceso como root (o mediante sudo) en la Orange Pi Zero 3W con DietPi.

Conexión a internet para instalar paquetes base y headers del kernel si están disponibles en los repositorios.

Respaldo previo de /boot/dietpiEnv.txt y /boot/dietpi.txt (el script crea copia de seguridad automática de dietpiEnv.txt).

Uso rápido
Clonar o copiar los archivos en la placa y dar permisos de ejecución al script principal:

Bash
chmod +x zero3w-master-setup.sh
Ejecutar el script como root:

Bash
sudo HEADLESS_MODE=1 CPU_GOVERNOR=performance ./zero3w-master-setup.sh
Variables disponibles:

HEADLESS_MODE=1 (por defecto): establece multi-user.target y compila/valida zero3w-headless-safe.dtbo junto con zero3w-opt.dtbo.

CPU_GOVERNOR=performance (por defecto): aplica el gobernador en los núcleos cpufreq y actualiza CONFIG_CPU_GOVERNOR en /boot/dietpi.txt si existe.

Reiniciar para cargar los overlays DTB:

Bash
sync && sudo reboot
Qué hace zero3w-master-setup.sh
Paquetes y herramientas (install_master_essentials): Instala compiladores (build-essential, cmake), utilidades de hardware y diagnóstico (pciutils, usbutils, i2c-tools, gpiod, lm-sensors, htop), device-tree-compiler (dtc / fdtoverlay) e intenta instalar linux-headers-$(uname -r) con respaldo a un conjunto mínimo de paquetes si no existe el paquete de headers exacto.

CPU y servicios (tune_cpu_and_services): Ajusta scaling_governor en los núcleos disponibles, actualiza CONFIG_CPU_GOVERNOR en /boot/dietpi.txt, deshabilita zero3w-gpio119.service y servicios NVMe-oF innecesarios (nvmefc-boot-connections.service, nvmf-autoconnect.service), habilita fstrim.timer y fija multi-user.target cuando HEADLESS_MODE=1.

Compilación y validación de overlays (build_and_install_zero3w_overlays):

Genera y compila /boot/overlay-user/zero3w-opt.dts (PD23 = gpio119 para PCIe, PD5 = gpio101 para ventilador, y deshabilita ufs@04520000, touchscreen@14, i2s0_mach y pwm-fan).

Genera y compila /boot/overlay-user/zero3w-headless-safe.dts (deshabilita nodos de display/DRM/HDMI/eDP/audio HDMI sin alterar el bus SDIO/Wi-Fi).

Valida la aplicación de los .dtbo sobre /boot/dtb/allwinner/sun60i-a733-orangepi-zero3w.dtb usando fdtoverlay antes de tocar /boot/dietpiEnv.txt.

Actualiza user_overlays en /boot/dietpiEnv.txt.

Verificación tras el reinicio
Tras reconectar por SSH, comprueba el estado del sistema:

Bash
systemd-analyze
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat /sys/kernel/debug/gpio | grep -E "101|119|PD5|PD23" || true
ip -br a show wlan0
lspci
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
Revisa también los registros del kernel por si algún nodo deshabilitado emite advertencias en tu versión específica del BSP:

Bash
dmesg -T | grep -iE "pcie|nvme|wlan|aic|drm|hdmi|regulator"
Notas de seguridad y mantenimiento
Pruebas graduales: Si cambias de versión de kernel o modificas nodos de Device Tree, verifica siempre con fdtoverlay y conserva un respaldo de /boot/dietpiEnv.txt y del DTB base.

Montaje persistente de NVMe: Si montas tu unidad NVMe en /mnt/nvme, configura la entrada correspondiente en /etc/fstab (preferiblemente usando UUID) y verifica con sudo mount -a.


---

<FollowUp label="¿Quieres que agregue al README una sección de benchmarks con fio y montaje en /etc/fstab?"
