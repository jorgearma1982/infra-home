## Instalación de Sistema Operativo Raspberry PI

## Introducción

Esta simple guia te ayudara a instalar el sistema operativo Raspberry PI en una máquina Raspberry PI, te voy a mostrar
como hacer las tareas de configuración básicas, como la configuración de la red, cambiar la contraseña, actualizar
el sistema e instalar paquetes y otras tareas.

## Requisitos

Para la configuración básica requerimos lo siguiente:

 * Tarjeta SD de 32 GB SD Card
 * Sistema Operativo Raspberry PI Lite (Legacy), de 32-bit con Debian 10 buster
 * Monitor con conexión HDMI ó adaptador VGA
 * Teclado USB
 * Conexión Ethernet
 * Direccionamiento IP Privado
 * Conexión a Internet

## Instalación

Para la instalación inicial voy a usar un sistema linux, necesitamos suficiente espacio en disco para descargar
la imagen del sistema operativo raspberry pi y un lector de tarjetas SD. Descargamos la imagen oficial desde la página:

 * [Raspberry PI OS Download page](https://www.raspberrypi.com/software/operating-systems/)

Extraemos el archivo de la imagen:

```
$ cd Downloads
$ ls *.xz
2022-04-04-raspios-buster-armhf-lite.img.xz
$ xz -d -v 2022-04-04-raspios-buster-armhf-lite.img.xz
$ ls *.img
2022-04-04-raspios-buster-armhf-lite.img
```

Descargamos `Raspberry PI Imager` desde la siguiente liga:

 * [Raspberry PI Imager](https://www.raspberrypi.com/software/)

Quemamos la imagen en una tarjeta SD. Después nos aseguramos que:

 * Instalar la tarjeta SD en la raspberry Pi
 * Conectar el cable HDMI al monitor
 * Conectar el cable Ethernet a la red local
 * Conectar el adaptador de corriente
 * Esperar a que el sistema arranque

## Cambiar la contraseña

Por razones de seguridad, debemos cambiar la contraseña predeterminada del usuario `pi`, hacemos login localmente
en el sistema, veremos algo así en pantalla:

```
Rasbpian GNU/Linux 10 raspberrypi tty1
raspberrypi login:
```

El usuario predeterminado es `pi` y `raspberry` su contraseña, ahora corremos `raspi-config` para actualizar la
contraseña:

```
$ sudo raspi-config
```

Vamos a el menú `1 System Options`, seleccionamos `S3 Password` y lo cambiamos:

## Expandir el sistema de archivos

El siguiente paso es expandir el sistema de archivos siguiendo los siguientes pasos:

```
$ sudo raspi-config
```

Vamos a el menú `Advanced Options` seleccionamos `A Expand Filesystem`, esperamos a que termine la operación para
terminar y salir de la herramienta, después reiniciamos:

```
$ sudo reboot
```

## Configuración de Red

Ahora podemos cambiar el nombre del host usando la herramienta `raspi-config`:

```
$ sudo raspi-config
```

Vamos al menú `1 System Options` seleccionamos `S4 Hostname`, escribimos el nombre del host y seleccionamos `OK`.

Configuramos la conexión Ethernet para la raspberry pi, edita el archivo de configuración del cliente DHCP:

```
$ sudo vim /etc/dhcpcd.conf
```

Al final del archivo agregamos las siguientes líneas para configurar el direccionamiento IP:

```
# LAN Interface
interface eth0
static ip_address=10.101.100.250/24
static routers=10.101.100.1
static domain_name_servers=8.8.8.8
```

Guardamos el archivo y reiniciamos el sistema:

```
$ sudo reboot
```

## Actualización del sistema

Ahora que el sistema tiene conectividad local e Internet, actualizamos la lista de paquetes de APT y actualizamos
el sistema:

```
$ sudo apt update
$ sudo apt upgrade
```

Después, reiniciamos la máquina:

```
$ sudo reboot
```

Esperamos, y después iniciamos sesión para realizar las siguientes tareas.

## Configuración SSH

Para administrar el sistema de forma remota a través de la red, habilita el servicio SSH:

```
$ sudo raspi-config
```

Vamos al menú `3 Interface Options` seleccionamos `P2 SSH`, confirmamos y finalizamos.

Opcionalmente puede instalar la llave SSH pública en el archivo de llaves autorizadas, por ejemplo:

```
$ mkdir .ssh
$ chmod 700
$ vim .ssh/authorized_keys
$ chmod 600
```

## Instalación de Paquetes

Instalemos algunos paquetes para administrar el sistema:

```
$ sudo apt install vim screen multitail htop
```

Ahora unas herramientas para administración de la red:

```
$ sudo apt curl wget iftop tcpdump tshark nmap
```

Limpiamos los paquetes:

```
$ sudo apt clean
$ sudo apt autoclean
```

## Respaldo de la tarjeta SD

Después de que haz hecho todas las tareas previas, se recomienda hacer una copia de seguridad de el contenido de
la tarjeta SD, así podrás tener u n respaldo en caso de que falle la tarjeta o en caso de que quieras instalar
el sistema de nuevo.

En linux usa `fdisk` para obtener el nombre del dispositivo de la tarjeta SD:

```
$ sudo fdisk -l
```

En macos usa `diskutil` para obtener el nombre del dispositivo:

```
$ sudo diskutil list
...
...
/dev/disk5 (external, physical):
 #:     TYPE NAME                    SIZE       IDENTIFIER
 0:     FDisk_partition_scheme      *15.5 GB    disk5
 1:     Windows_FAT_32 boot          268.4 MB   disk5s1
 2:     Linux                        15.2 GB    disk5s2
```

El nombre del dispositivo es `/dev/disk5`.

```
$ sudo dd if=/dev/disk5 of=raspberry_pi_buster_base.img bs=4M
```

Esperamos a que la operación termine y al final expulsamos la tarjeta SD.

## Desactivando WIFI y Bluetooth

Editamos el archivo `/boot/config.txt`:

```
sudo vi /boot/config.txt
```

Para desactivar el soporte de WIFI y bluetooth, al final agregamos las siguiente líneas:

```
...
...
# Disable wifi and bluetooth
dtoverlay=disable-wifi
dtoverlay=disable-bt
```

Desactivamos los servicios permanentemente:

```
$ sudo systemctl disable hciuart.service
$ sudo systemctl disable bluealsa.service
$ sudo systemctl disable bluetooth.service
```

## Desactivamos servicios sin usar

Desactivamos avahi-daemon:

```
$ sudo systemctl stop avahi-daemon
$ sudo systemctl disable avahi-daemon
```

Desactivamos triggerhappy:

```
$ sudo systemctl stop triggerhappy
$ sudo systemctl disable triggerhappy
```

Desactivamos wpa_supplicant:

```
$ sudo systemctl stop wpa_supplicant
$ sudo systemctl disable wpa_supplicant
```

## Referencias

Dejamos las siguientes referencias externas para complementar la documentación:

 * [Raspberry Pi](https://www.raspberrypi.com/)
 * [Raspberry PI Software](https://www.raspberrypi.com/software/)
 * [Raspberry PI Documentation](https://www.raspberrypi.com/documentation/)
