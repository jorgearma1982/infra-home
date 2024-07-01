## Instalación de Sistema Operativo Raspberry PI

## Introducción

Esta simple guia te ayudara a instalar el sistema operativo Raspberry PI en una máquina Raspberry PI, te voy a mostrar
como hacer las tareas de configuración básicas como cambiar la contraseña, la configuración de la red y actualizar
el sistema.

## Requisitos

* Tarjeta SD de 32 GB SD Card
* Sistema Operativo Raspberry Pi OS Lite, de 64-bit con Debian 12 bookworm
* Monitor con conexión HDMI ó adaptador VGA
* Teclado USB
* Conexión Ethernet
* Direccionamiento IP Privado
* Conexión a Internet

## Instalación

Para la instalación inicial voy a usar un sistema linux, necesitamos suficiente espacio en disco para descargar
la imagen del sistema operativo raspberry pi y un lector de tarjetas SD. Descargamos la imagen oficial:

* [Raspberry PI OS Download page](https://www.raspberrypi.com/software/operating-systems/)

Extraemos el archivo de la imagen:

```shell
xz -d -v 2024-03-15-raspios-bookworm-arm64-lite.img.xz
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
en el sistema.

El usuario predeterminado es `pi` y `raspberry` su contraseña, ahora corremos `raspi-config` para actualizar la
contraseña:

```shell
sudo raspi-config
```

Vamos a el menú `1 System Options`, seleccionamos `S3 Password` y lo cambiamos.

## Configuración de Red

Cambiamos el nombre del host usando la herramienta `raspi-config`:

```shell
sudo raspi-config
```

Vamos al menú `1 System Options` seleccionamos `S4 Hostname`, escribimos el nombre del host y seleccionamos `OK`.

La conectividad de el servidor será por cable Ethernet, la dirección de red se asigna vía DHCP.

## Actualización del sistema

Actualizamos la lista de paquetes de APT y actualizamos el sistema:

```shell
sudo apt update
sudo apt upgrade
sudo reboot
```

## Referencias

Dejamos las siguientes referencias externas para complementar la documentación:

* [Raspberry Pi](https://www.raspberrypi.com/)
* [Raspberry PI Software](https://www.raspberrypi.com/software/)
* [Raspberry PI Documentation](https://www.raspberrypi.com/documentation/)
