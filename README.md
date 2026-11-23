# PCIe Enablement with Waveshare PCIe to M.2 Board (C) Rev2.0 and DTB Integration on Orange Pi Zero 3W (`sun60i-a733`)

## 1. Hardware and System Context

- **Board:** Orange Pi Zero 3W with Allwinner **A733** (`sun60i-a733`) SoC.
- **External PCIe Adapter:** **Waveshare PCIe to M.2 Board (C) Rev2.0** (connected via a 50 mm flat PCIe FPC cable, Type D/B, with HAT-style / stacked form factor compatibility similar to Raspberry Pi 5 M.2 HAT+).
- **OS and Kernel:** **DietPi** running kernel `6.6.98-vendor-sun60iw2`.
- **Goal:** Enable the **Waveshare PCIe to M.2 Board (C) Rev2.0** and NVMe drive enumeration on the board, progressing from manual GPIO probing and hot-plug tests to a persistent *Device Tree* (DTB) overlay integration.

---

## 2. Pin Compatibility with Raspberry Pi Adapters

Expansion HATs and adapters designed for a 40-pin Raspberry Pi header—such as the **Waveshare PCIe to M.2 Board (C) Rev2.0** and Raspberry Pi 5 M.2 HAT+ style layouts—share physical header alignment and baseline power/control pins, allowing mechanical fitting on the board header. However, internal GPIO numbering, pin controller (`pinctrl`) definitions, and *Device Tree* nodes belong to the Allwinner `sun60i-a733` SoC rather than Broadcom, so control of the enable line (`PD23` / `gpio119`) is handled through the Orange Pi Zero 3W kernel/DTB layer.

---

## 3. Evolution: GPIO Search, Hot-Plug, Service, and DTB

| Stage | Implementation | Purpose | Transition |
| :--- | :--- | :--- | :--- |
| **Sequential GPIO Search** | Test script across GPIO lines | Identify which pin controls power enable for the **Waveshare PCIe to M.2 Board (C) Rev2.0** | Establishes target pin (`PD23` / `gpio119`) |
| **Hot-Plug Activation** | Script to power the adapter and trigger `/sys/bus/pci/rescan` | Detect and enumerate a connected SSD without a full reboot | Automated as a startup service |
| **Systemd Service** | Earlier userspace unit (`zero3w-gpio119.service`) | Apply pin state after boot | Disabled once moved to DTB |
| **DTB Integration** | Overlay `/boot/overlay-user/zero3w-opt.dts` + `dietpiEnv.txt` | Declare the rail as `regulator-fixed` in the Device Tree | Clean, boot-time integration |

---

## 4. Hot-Plug Script and Systemd Service Transition

### PCIe Hot-Plug / Bus Rescan Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# Trigger PCIe bus rescan after powering the Waveshare PCIe to M.2 Board (C) Rev2.0 and SSD
if [ -e /sys/bus/pci/rescan ]; then
  echo 1 > /sys/bus/pci/rescan
fi

lspci -nn
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
```

### Transitioning from Systemd Service to DTB

During earlier userspace testing, `zero3w-gpio119.service` handled the pin via `sysfs`. After defining the rail as a `regulator-fixed` node in the *Device Tree*, the legacy service is disabled:

```bash
sudo systemctl disable zero3w-gpio119.service 2>/dev/null || true
```

---

## 5. DTB Overlay (`zero3w-opt.dts`) and Integration Steps

The PCIe power rail (`PD23` / `gpio119`) for the **Waveshare PCIe to M.2 Board (C) Rev2.0** is defined as a `regulator-fixed` node in `/boot/overlay-user/zero3w-opt.dts`, alongside disabling unused nodes in the optimization fragments:

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

### Compile, Validate, and Enable

1. **Compile `.dts` into `.dtbo`:**

   ```bash
   sudo mkdir -p /boot/overlay-user
   sudo dtc -@ -I dts -O dtb -o /boot/overlay-user/zero3w-opt.dtbo /boot/overlay-user/zero3w-opt.dts
   ```

2. **Validate offline with `fdtoverlay` against the base DTB:**

   ```bash
   sudo fdtoverlay -i /boot/dtb/allwinner/sun60i-a733-orangepi-zero3w.dtb \
     -o /tmp/zero3w-merged-check.dtb \
     /boot/overlay-user/zero3w-opt.dtbo
   rm -f /tmp/zero3w-merged-check.dtb
   ```

3. **Back up `/boot/dietpiEnv.txt`, configure `user_overlays`, and reboot:**

   ```bash
   sudo cp -a /boot/dietpiEnv.txt "/boot/dietpiEnv.txt.bak.$(date +%Y%m%d%H%M%S)"
   ```

   Ensure `user_overlays=zero3w-opt` (or your active overlay list) is set in `/boot/dietpiEnv.txt`, disable `zero3w-gpio119.service`, and reboot with `sync && sudo reboot`.

---

## 6. Photos (Optional)

Add photos to a folder such as `docs/` or `assets/` in your repository and reference them with relative paths:

```markdown
![Waveshare PCIe to M.2 Board (C) Rev2.0 setup on Orange Pi Zero 3W](docs/zero3w-waveshare-setup.jpg)
```

---

## 7. Post-Reboot Verification

```bash
lspci
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
dmesg -T | grep -iE "pcie|nvme|regulator|119|PD23"
```
