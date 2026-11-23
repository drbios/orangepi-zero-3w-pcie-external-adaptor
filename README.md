MEMORIA TÉCNICA DE HARDWARE Y SISTEMA
Activación de PCIe Externo Waveshare en Orange Pi Zero 3W
Recorrido de diagnóstico, compatibilidad de pines, búsqueda de GPIO, activación en caliente con SSD NVMe, servicio systemd e integración definitiva en Device Tree (DTB) sobre Allwinner sun60i-a733 en DietPi.

1.	Origen de la Búsqueda: Kernel, Distro y Adaptador Waveshare
El trabajo nació de la necesidad de aprovechar el enlace PCIe de la Orange Pi Zero 3W (SoC Allwinner A733, sun60i-a733 ) ejecutando DietPi con kernel vendor/BSP de la familia
(como la serie	). Aunque el silicio y el controlador PCIe subyacente están
presentes en la plataforma, conectar un adaptador PCIe externo Waveshare con una unidad SSD NVMe no levantaba el enlace de forma automática ni exponía el disco de manera confiable tras el arranque.

En placas SBC recientes con controladores PCIe integrados o puentes externos, el rail de alimentación de 3.3 V (o habilitación de enlace/reset del adaptador) a menudo depende de una línea GPIO controlada por el SoC. Si esa línea no pasa a estado activo alto en el momento adecuado, el dispositivo NVMe no recibe energía estable o el controlador PCIe no completa la enumeración del bus durante el arranque del kernel.

2.	Por Qué Son Compatibles los Pines de Adaptadores RPI y Orange Pi Zero
Los adaptadores y HATs pensados para cabecera de 40 pines tipo Raspberry Pi (RPI) y las placas de la familia Orange Pi Zero comparten una distribución física y eléctrica heredada del estándar de cabecera de expansión de 40 contactos (paso de 2,54 mm). Los pines de alimentación principales
 
(
 
y
 
), tierra (
 
) y buses comunes como
 
,
 
y
 
ocupan posiciones físicas
 
equivalentes en el conector.

Esta compatibilidad física permite acoplar mecánicamente el adaptador Waveshare y suministrar rails de potencia sin modificar el conector, pero no garantiza que el número de GPIO en Linux ni el controlador de pines coincidan. En Raspberry Pi la numeración BCM sigue un esquema propio,
mientras que en Allwinner	los pines se agrupan por puertos (como el puerto	,
 
donde
 
corresponde al índice
 
y
 
corresponde a
 
). Por ello, un HAT o
 
adaptador que utiliza un pin de control genérico exige identificar qué línea real del controlador de Allwinner gobierna la habilitación en la placa.
 
Esta compatibilidad física permite acoplar mecánicamente el adaptador Waveshare y suministrar rails de potencia sin modificar el conector, pero no garantiza que el número de GPIO en Linux ni el controlador de pines coincidan. En Raspberry Pi la numeración BCM sigue un esquema propio,
mientras que en Allwinner	los pines se agrupan por puertos (como el puerto	,
 
donde
 
corresponde al índice
 
). Por ello, un HAT o adaptador que utiliza un pin de
 
control genérico exige identificar qué línea real del controlador habilitación en la placa.
 
de Allwinner gobierna la
 

 

Señal / Función	Pin / Línea en Zero 3W	Comportamiento Requerido	Rol en la Integración
Habilitación PCIe (Waveshare)	PD23 / gpio119 ( &pio 3 23 0 )	Salida en nivel alto ( out hi )	Alimenta / habilita el adaptador PCIe y permite enumerar el SSD NVMe.
Conectividad inalámbrica	Bus SDIO / sdmmc@4022000	Activo y sin bloquear	Preserva el funcionamiento de wlan0 al limpiar nodos innecesarios.
3.	Secuencia de Búsqueda de GPIO y Activación en Caliente del SSD
Para localizar qué GPIO habilitaba el adaptador PCIe sin adivinar a ciegas, se empleó un enfoque metódico de prueba secuencial sobre líneas candidatas, observando tanto el estado de los pines como la aparición del enlace PCIe y del dispositivo de bloques NVMe en el kernel (mediante	,
y los mensajes de	).

Un aspecto clave durante las pruebas fue la activación con el SSD conectado en caliente (o con el adaptador ya acoplado mientras el sistema estaba encendido): al conmutar la línea GPIO correcta a nivel alto, se energizaba el adaptador y se provocaba o reescaneaba la enumeración del bus PCIe para que el controlador detectara el endpoint NVMe y creara el nodo de bloque (por ejemplo
) sin necesidad de apagar físicamente toda la placa en cada prueba.
 






















Una vez identificada la línea	( gpio119 ) para el adaptador PCIe, se estructuró el script de
activación para asegurar que el pin quedara en salida alta, se diera tiempo de estabilización eléctrica al adaptador y al SSD, y se forzara el reescaneo del bus PCIe si el kernel no había enumerado el dispositivo automáticamente tras energizarlo.
 
4.	De Script Manual a Servicio systemd e Integración en DTB
Ejecutar el script manualmente tras cada inicio funcionaba para validar el hardware, pero resultaba frágil en un equipo de operación continua. El siguiente paso fue encapsular la activación en un
 
servicio
 
(como
 
) que se ejecutara temprano en el arranque
 
para poner el pin en alto y dejar disponible el almacenamiento antes de que dependieran de él otros servicios o montajes.

Sin embargo, depender únicamente de scripts en userspace o de	presenta limitaciones: el
estado inicial del pin queda supeditado al orden de arranque de unidades y el kernel no conoce formalmente la relación de alimentación del hardware. Por ello, la solución definitiva consistió en
migrar la habilitación de	( gpio119 ) directamente al Device Tree (DTB) mediante un overlay
cargado por el gestor de arranque U-Boot antes de que el kernel inicialice el bus PCIe.

5.	Archivo Overlay DTB y Procedimiento de Integración
Para integrar la habilitación en el DTB sin modificar el archivo binario base del kernel, se creó el
 
fuente de overlay
 

usando el controlador estándar
 
. En su
 
se declara el nodo del kernel Linux, enlazando el
 
controlador de pines
 
al puerto
 
(banco
 
), línea
 
( PD23 =
 
), con polaridad
 
activa alta y encendido automático desde el arranque (	y
).
 








































La integración segura del overlay en DietPi se realizó en cuatro pasos verificables:

 
1.	Compilación del overlay con símbolos: Se compiló el fuente
 
a binario
 
mediante
 

 
 
(el parámetro
).
 
conserva la tabla de símbolos necesaria para resolver
 
2.	Validación offline contra el DTB base: Antes de tocar la configuración de arranque, se probó la fusión en memoria/temporal usando
para
confirmar que todas las rutas y referencias de nodos resolvieran sin errores.
 
3.	Registro en	y limpieza de servicios previos: Se respaldó
 
, se añadió
 
en la directiva
 
para que U-Boot
 
lo aplique en cada arranque, y se deshabilitó el antiguo servicio de userspace ( systemctl
) para evitar conflictos de propiedad sobre el GPIO.

 
4.	Verificación tras el reinicio: Con confirmó que el regulador
 

reclama
 

en estado
 
y
 
se directamente
 
desde el kernel y enumera el SSD NVMe sin intervención tardía.
