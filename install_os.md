## Raspberry PI OS Installation

## Introduction

This simple guide helps you install the Raspberry PI OS on a Raspberry PI machine, I'm going to show you how to do
the basic configuration tasks like setting up the network, change password, update the system and install packages.

## Requirements

For the base setup we require the follow:

 * 32 GB SD Card, use any with high density
 * Raspberry PI OS Lite (Legacy), 32-bit with Debian 10 buster
 * Monitor with HDMI Connection or VGA Adapter
 * USB Keyboard
 * Ethernet network connection
 * Private IP Addressing
 * Internet connection

## Installation

For the initial installation we are going to us a linux system, we need sufficient disk space to download the raspberry
Pi Operating system image and a SD Card reader.  Download the official image for Raspberry PI operation system from
the page:

 * [Raspberry PI OS Download page](https://www.raspberrypi.com/software/operating-systems/)

Then extract the image file:

```
$ cd Downloads
$ ls *.xz
2022-04-04-raspios-buster-armhf-lite.img.xz
$ xz -d -v 2022-04-04-raspios-buster-armhf-lite.img.xz
$ ls *.img
2022-04-04-raspios-buster-armhf-lite.img
```

Download `Raspberry PI Imager` from the follow link:

 * [Raspberry PI Imager](https://www.raspberrypi.com/software/)

Burn the image on SD card, and eject the card. After that be sure to:

 * Install the SD Card on your raspberry PI
 * Connect a HDMI cable to your monitor
 * Connect a Ethernet cable to your local network
 * Connect the power adapter
 * Wait for the system to boot

## Change password

For security reasons, we need to change the default system user password for the `pi` user, log in locally to the
pi, you will see something like this at your screen:

```
Rasbpian GNU/Linux 10 raspberrypi tty1
raspberrypi login:
```

The default user is `pi` and `raspberry` the password, now run `raspi-config` to update the password.

```
$ sudo raspi-config
```

Go to the `1 System Options` menu, then select `S3 Password` and change it.

## Resize disk

The next step is to Expand the file system by following these steps:

```
$ sudo raspi-config
```

Go to the `Advanced Options` menu then select `A Expand Filesystem`, wait for the operation to finish and then exit
the tool and reboot.

```
$ sudo reboot
```

## Network Setup

Now we can change the system host name using `raspi-config` tool:

```
$ sudo raspi-config
```

Go to the `1 System Options` menu then select `S4 Hostname`, enter the new host name, and select `OK`.

Let's setup the Ethernet connection for your raspberry pi, edit the configuration file for the `DHCP client`:

```
$ sudo vim /etc/dhcpcd.conf
```

At the end of the file add this lines to set up a IP addressing:

```
# LAN Interface
interface eth0
static ip_address=10.101.100.250/24
static routers=10.101.100.1
static domain_name_servers=8.8.8.8
```

Save the file and reboot the system:

```
$ sudo reboot
```

## Update the system

Now that we have local and internet connection, Update apt package list and upgrade the system:

```
$ sudo apt update
$ sudo apt upgrade
```

After that reboot your pi machine

```
$ sudo reboot
```

Wait and log in again to continue with the following tasks.

## SSH Setup

Finally, to be able to remotely admin your new system, enable the SSH service:

```
$ sudo raspi-config
```

Go to the `3 Interface Options` menu then select `P2 SSH`, confirm and finish.

## Install Packages

Let's install some packages to help feel like home:

```
$ sudo apt install vim screen multitail htop
```

Network tooling:

```
$ sudo apt curl wget iftop tcpdump tshark nmap
```

And clean up packages:

```
$ sudo apt clean
$ sudo apt autoclean
```

## References

Please follow these external documentation:

 * [Raspberry Pi](https://www.raspberrypi.com/)
 * [Raspberry PI Software](https://www.raspberrypi.com/software/)
 * [Raspberry PI Documentation](https://www.raspberrypi.com/documentation/)
