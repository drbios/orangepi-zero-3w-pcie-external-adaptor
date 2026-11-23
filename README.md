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
