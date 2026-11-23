<TaggedPDF-doc>
<?xpacket begin='﻿' id='W5M0MpCehiHzreSzNTczkc9d'?>
<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="Adobe XMP Core 9.1-c001 79.675d0f7, 2023/06/11-19:21:16 ">
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmlns:pdf="http://ns.adobe.com/pdf/1.3/" xmlns:dc="http://purl.org/dc/elements/1.1/" rdf:about="">
<xmp:CreateDate>2026-11-23T11:50:43Z</xmp:CreateDate>
<xmp:CreatorTool>Chromium</xmp:CreatorTool>
<xmp:ModifyDate>2026-11-23T11:50:43Z</xmp:ModifyDate>
<pdf:Producer>Skia/PDF m136</pdf:Producer>
<dc:format>xml</dc:format>
<dc:title>
<rdf:Alt>
<rdf:li xml:lang="x-default">Informe Técnico: Activación PCIe Externo Waveshare en Orange Pi Zero 3W</rdf:li>
</rdf:Alt>
</dc:title>
</rdf:Description>
</rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>
<?xpacket end='r'?>
<P>MEMORIA TÉCNICA DE HARDWARE Y SISTEMA </P>
<Part>
<H5>Activación de PCIe Externo Waveshare en Orange Pi Zero 3W </H5>
<P>Recorrido de diagnóstico, compatibilidad de pines, búsqueda de GPIO, activación en caliente con SSD NVMe, servicio systemd e integración definitiva en Device Tree (DTB) sobre Allwinner sun60ia733 en DietPi. </P>
<P>1. Origen de la Búsqueda: Kernel, Distro y Adaptador Waveshare </P>
<P>
El trabajo nació de la necesidad de aprovechar el enlace PCIe de la Orange Pi Zero 3W (SoC Allwinner A733,
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_0.jpg"/>
</Figure>
sun60i-a733 ) ejecutando DietPi con kernel vendor/BSP de la familia
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_1.jpg"/>
</Figure>
sun60iw2 (como la serie
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_2.jpg"/>
</Figure>
6.6.98-vendor-sun60iw2 ). Aunque el silicio y el controlador PCIe subyacente están presentes en la plataforma, conectar un adaptador PCIe externo Waveshare con una unidad SSD NVMe no levantaba el enlace de forma automática ni exponía el disco de manera confiable tras el arranque.
</P>
<P>En placas SBC recientes con controladores PCIe integrados o puentes externos, el rail de alimentación de 3.3 V (o habilitación de enlace/reset del adaptador) a menudo depende de una línea GPIO controlada por el SoC. Si esa línea no pasa a estado activo alto en el momento adecuado, el dispositivo NVMe no recibe energía estable o el controlador PCIe no completa la enumeración del bus durante el arranque del kernel. </P>
<P>2. Por Qué Son Compatibles los Pines de Adaptadores RPI y Orange Pi Zero </P>
<P>
Los adaptadores y HATs pensados para cabecera de 40 pines tipo Raspberry Pi (RPI) y las placas de la familia Orange Pi Zero comparten una distribución física y eléctrica heredada del estándar de cabecera de expansión de 40 contactos (paso de 2,54 mm). Los pines de alimentación principales (
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_3.jpg"/>
</Figure>
5V y
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_4.jpg"/>
</Figure>
3.3V ), tierra (
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_5.jpg"/>
</Figure>
GND ) y buses comunes como
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_6.jpg"/>
</Figure>
I2C ,
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_7.jpg"/>
</Figure>
SPI y
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_8.jpg"/>
</Figure>
UART ocupan posiciones físicas equivalentes en el conector.
</P>
<P>
Esta compatibilidad física permite acoplar mecánicamente el adaptador Waveshare y suministrar rails de potencia sin modificar el conector, pero no garantiza que el número de GPIO en Linux ni el controlador de pines coincidan. En Raspberry Pi la numeración BCM sigue un esquema propio, mientras que en Allwinner
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_9.jpg"/>
</Figure>
sun60i-a733 los pines se agrupan por puertos (como el puerto
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_10.jpg"/>
</Figure>
PD , donde
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_11.jpg"/>
</Figure>
PD23 corresponde al índice
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_12.jpg"/>
</Figure>
gpio119 y
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_13.jpg"/>
</Figure>
PD5 corresponde a
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_14.jpg"/>
</Figure>
gpio101 ). Por ello, un HAT o adaptador que utiliza un pin de control genérico exige identificar qué línea real del controlador
</P>
<P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_15.jpg"/>
</Figure>
pinctrl de Allwinner gobierna la habilitación en la placa.
</P>
<P>
Esta compatibilidad física permite acoplar mecánicamente el adaptador Waveshare y suministrar rails de potencia sin modificar el conector, pero no garantiza que el número de GPIO en Linux ni el controlador de pines coincidan. En Raspberry Pi la numeración BCM sigue un esquema propio, mientras que en Allwinner
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_16.jpg"/>
sun60i-a733
</Figure>
los pines se agrupan por puertos (como el puerto donde
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_17.jpg"/>
PD23
</Figure>
corresponde al índice
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_18.jpg"/>
gpio119 ). Por ello,
</Figure>
un HAT o adaptador que utiliza un pin de control genérico exige identificar qué línea real del controlador
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_19.jpg"/>
pinctrl
</Figure>
de Allwinner gobierna la habilitación en la placa.
</P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_20.jpg"/>
PD ,
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_21.jpg"/>
Señal / Función
</Figure>
<Table>
<TR>
<TH>Señal / Función </TH>
<TH>Pin / Línea en Zero 3W </TH>
<TH>Comportamiento Requerido </TH>
<TH>Rol en la Integración </TH>
</TR>
<TR>
<TD>Habilitación PCIe (Waveshare) </TD>
<TD>PD23 / gpio119 ( &pio 3 23 0 ) </TD>
<TD>Salida en nivel alto ( out hi ) </TD>
<TD>Alimenta / habilita el adaptador PCIe y permite enumerar el SSD NVMe. </TD>
</TR>
<TR>
<TD>Conectividad inalámbrica </TD>
<TD>Bus SDIO / sdmmc@4022000 </TD>
<TD>Activo y sin bloquear </TD>
<TD>Preserva el funcionamiento de wlan0 al limpiar nodos innecesarios. </TD>
</TR>
</Table>
<P>3. Secuencia de Búsqueda de GPIO y Activación en Caliente del SSD </P>
<P>Para localizar qué GPIO habilitaba el adaptador PCIe sin adivinar a ciegas, se empleó un enfoque metódico de prueba secuencial sobre líneas candidatas, observando tanto el estado de los pines como la aparición del enlace PCIe y del dispositivo de bloques NVMe en el kernel (mediante </P>
<P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_22.jpg"/>
lsblk
</Figure>
y los mensajes de
</P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_23.jpg"/>
dmesg ).
</Figure>
<P>Un aspecto clave durante las pruebas fue la activación con el SSD conectado en caliente (o con el adaptador ya acoplado mientras el sistema estaba encendido): al conmutar la línea GPIO correcta a nivel alto, se energizaba el adaptador y se provocaba o reescaneaba la enumeración del bus PCIe para que el controlador detectara el endpoint NVMe y creara el nodo de bloque (por ejemplo </P>
<P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_24.jpg"/>
</Figure>
nvme0n1 ) sin necesidad de apagar físicamente toda la placa en cada prueba.
</P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_25.jpg"/>
lspci ,
</Figure>
<P>#!/usr/bin/env bash </P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_26.jpg"/>
</Figure>
<P>set -euo pipefail </P>
<P># Secuencia de prueba controlada sobre candidatos GPIO (ajustar lista según banco) CANDIDATES=(118 119 120) </P>
<P>for pin in "${CANDIDATES[@]}"; do </P>
<P>echo "Probando GPIO ${pin}..." </P>
<P>if [ ! -d "/sys/class/gpio/gpio${pin}" ]; then </P>
<P>echo "${pin}" > /sys/class/gpio/export 2>/dev/null || continue </P>
<P>fi </P>
<P>echo "out" > "/sys/class/gpio/gpio${pin}/direction" 2>/dev/null || true </P>
<P>echo "1" > "/sys/class/gpio/gpio${pin}/value" 2>/dev/null || true </P>
<P>sleep 1 </P>
<P>if command -v lspci >/dev/null 2>&1; then </P>
<P>lspci || true </P>
<P>fi </P>
<P>lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "nvme|NAME" || true done </P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_27.jpg"/>
PD23 ( gpio119 ) para el adaptador PCIe,
</Figure>
<P>Una vez identificada la línea se estructuró el script de activación para asegurar que el pin quedara en salida alta, se diera tiempo de estabilización eléctrica al adaptador y al SSD, y se forzara el reescaneo del bus PCIe si el kernel no había enumerado el dispositivo automáticamente tras energizarlo. </P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_28.jpg"/>
</Figure>
<P>#!/usr/bin/env bash set -euo pipefail </P>
<P>PCIE_GPIO=119 </P>
<P>if [ ! -d "/sys/class/gpio/gpio${PCIE_GPIO}" ]; then echo "${PCIE_GPIO}" > /sys/class/gpio/export fi </P>
<P>echo "out" > "/sys/class/gpio/gpio${PCIE_GPIO}/direction" echo "1" > "/sys/class/gpio/gpio${PCIE_GPIO}/value" sleep 1 </P>
<P># Reescaneo del bus PCIe para enumerar el SSD conectado en caliente if [ -w /sys/bus/pci/rescan ]; then </P>
<P>echo 1 > /sys/bus/pci/rescan fi sleep 1 lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT </P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_29.jpg"/>
PD23
</Figure>
<P>4. De Script Manual a Servicio systemd e Integración en DTB </P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_30.jpg"/>
servicio systemd(como zero3w-gpio119.service ) que
</Figure>
<P>Ejecutar el script manualmente tras cada inicio funcionaba para validar el hardware, pero resultaba frágil en un equipo de operación continua. El siguiente paso fue encapsular la activación en un </P>
<P>se ejecutara temprano en el arranque para poner el pin en alto y dejar disponible el almacenamiento antes de que dependieran de él otros servicios o montajes. </P>
<P>
Sin embargo, depender únicamente de scripts en userspace o de
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_31.jpg"/>
sysfs
</Figure>
presenta limitaciones: el estado inicial del pin queda supeditado al orden de arranque de unidades y el kernel no conoce formalmente la relación de alimentación del hardware. Por ello, la solución definitiva consistió en migrar la habilitación de ( gpio119 ) directamente al Device Tree (DTB) mediante un overlay cargado por el gestor de arranque U-Boot antes de que el kernel inicialice el bus PCIe.
</P>
<P>5. Archivo Overlay DTB y Procedimiento de Integración </P>
<P>Para integrar la habilitación en el DTB sin modificar el archivo binario base del kernel, se creó el </P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_32.jpg"/>
fuente de overlay /boot/overlay-user/zero3w-opt.dts . En su fragment@0 se declara el nodo
</Figure>
<P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_33.jpg"/>
zero3w-pcie-en
</Figure>
usando el controlador estándar
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_34.jpg"/>
regulator-fixed
</Figure>
del kernel Linux, enlazando el controlador de pines
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_35.jpg"/>
&pio
</Figure>
al puerto
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_36.jpg"/>
3
</Figure>
(banco
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_37.jpg"/>
PD ), línea
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_38.jpg"/>
23
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_39.jpg"/>
( PD23
</Figure>
=
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_40.jpg"/>
gpio119 ),
</Figure>
con polaridad
</P>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_41.jpg"/>
activa alta y encendido automático desde el arranque ( regulator-boot-on y regulator-always-on ).
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_42.jpg"/>
</Figure>
<P>/dts-v1/; /plugin/; </P>
<P>/{ fragment@0 { target-path = "/"; __overlay__ { </P>
<P>zero3w-pcie-en { compatible = "regulator-fixed"; regulator-name = "zero3w-pcie-en"; </P>
<P>regulator-min-microvolt = <3300000>; regulator-max-microvolt = <3300000>; gpio = <&pio 3 23 0>; /* PD23 = gpio119, active </P>
<P>high */ enable-active-high; regulator-boot-on; </P>
<P>regulator-always-on; }; }; }; </P>
<P>fragment@1 { target-path = "/soc@3000000/ufs@04520000"; __overlay__ { status = "disabled"; }; </P>
<P>}; </P>
<P>fragment@2 { target-path = "/soc@3000000/twi@251C000/touchscreen@14"; __overlay__ { status = "disabled"; }; </P>
<P>}; </P>
<P>fragment@3 { target-path = "/soc@3000000/i2s0_mach"; __overlay__ { status = "disabled"; }; }; }; </P>
<P>La integración segura del overlay en DietPi se realizó en cuatro pasos verificables: </P>
<L>
<L>
<LI>
1. Compilación del overlay con símbolos: Se compiló el fuente
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_43.jpg"/>
.dts
</Figure>
a binario
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_44.jpg"/>
.dtbo
</Figure>
mediante
</LI>
<LI>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_45.jpg"/>
user/zero3w-opt.dts &pio ).
</Figure>
(el parámetro
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_46.jpg"/>
-@
</Figure>
conserva la tabla de símbolos necesaria para resolver
</LI>
</L>
<L>
<LI>
<Lbl>2. </Lbl>
<LBody>Validación offline contra el DTB base: Antes de tocar la configuración de arranque, se probó la fusión en memoria/temporal usando </LBody>
</LI>
<LI>confirmar que todas las rutas y referencias de nodos resolvieran sin errores. </LI>
</L>
<L>
<LI>
3. Registro en
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_47.jpg"/>
/boot/dietpiEnv.txt
</Figure>
y limpieza de servicios previos: Se respaldó
</LI>
<LI>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_48.jpg"/>
/boot/dietpiEnv.txt ,
</Figure>
se añadió
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_49.jpg"/>
zero3w-opt
</Figure>
en la directiva
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_50.jpg"/>
user_overlays=
</Figure>
para que U-Boot lo aplique en cada arranque, y se deshabilitó el antiguo servicio de userspace (
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_51.jpg"/>
</Figure>
systemctl
</LI>
</L>
<LI>
<Lbl>4. </Lbl>
<LBody>
Verificación tras el reinicio: Con confirmó que el regulador
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_52.jpg"/>
zero3w-pcie-en
</Figure>
reclama
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_53.jpg"/>
gpio-119
</Figure>
en estado
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_54.jpg"/>
out hi
</Figure>
directamente desde el kernel y enumera el SSD NVMe sin intervención tardía.
</LBody>
</LI>
</L>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_55.jpg"/>
dtc -@ -I dts -O dtb -o /boot/overlay-user/zero3w-opt.dtbo /boot/overlay-
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_56.jpg"/>
fdtoverlay -i /boot/dtb/allwinner/sun60i-a733-
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_57.jpg"/>
orangepi-zero3w.dtb -o /tmp/zero3w-check.dtb /boot/overlay-user/zero3w-opt.dtbo para
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_58.jpg"/>
disable zero3w-gpio119.service ) para evitar conflictos de propiedad sobre el GPIO.
</Figure>
<Figure>
<ImageData src="images/Informe Técnico — Activación PCIe Externo Waveshare en Orange Pi Zero 3W_img_59.jpg"/>
cat /sys/kernel/debug/gpio | grep 119 y lspci se
</Figure>
</Part>
</TaggedPDF-doc>
