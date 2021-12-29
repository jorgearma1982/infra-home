# ansible-k3s

## Introducción

En este repositorio tenemos los playbooks de ansible para automatizar la instalación y configuración de un
cluster de Kubernetes usando `k3s` sobre `Raspberry Pi OS` (buster 10).

`k3s` es una distribución de kubernetes certificada, nos permite construir un cluster altamente disponible. Está
diseñado para cargas de trabajo Edge productivas, desatendidas, con recursos limitados, y en locaciones lejanas
(work from home) ó en artefactos IoT.

Es un sistema simplificado y seguro ya que esta empaquetado en un solo binario de <50MB que reduce las dependencias
y pasos para instalar, ejecutar y auto-actualizar un cluster de producción.

Soporta arquitecturas `ARM64` y `ARMv7`, funciona muy bien desde algo tan pequeño coo una Raspberry Pi hasta en una
instancia de AWS `a1.4xlarge` con 32GiB.

## Requisitos

Necesitamos cuatro máquinas, una desde donde usaremos ansible, diremos que es el nodo controlador, y las otras
máquinas serán la que controlaremos. Los nodos serán llamados así:

* localdev: maquina del desarrollador, ansible nodo controlador
* k3s-master: maquina cluster kubernetes, ansible nodo controlado
* k3s-worker1: maquina cluster kubernetes, ansible nodo controlado
* k3s-worker2: maquina cluster kubernetes, ansible nodo controlado

Los maquinas del cluster `k3s` ya deben tener instalado el sistema operativo Raspberry Pi OS 10 (buster), debe tener
configurada la interfaz WIFI conectada solo para administración (sin servidores dns ni gateway), la interfaz ethernet
debe estar configurada con dirección IP estática, con dns y gateway. El servicio SSH debe estar configurado para
permitir las conexiones remotas. Se debe generar una contraseña para el usuario local `pi` para evitar usar la
contraseña predeterminada.

## Instalación y configuración

Debes instalar ansible localmente en la maquina nodo controlador, puede ser en Linux o MacOS siguiendo
las siguientes instrucciones:

**Linux:**

```
$ sudo apt install python3
$ pip3 install ansible
```

**MacOS:**

```
$ brew install python3
$ pip3 install ansible
```

Verifica que ansible está instalado:

```
$ ansible --version
```

Ahora debes generar tus llaves RSA usando el script:

```
$ scripts/generate-ssh-keys.sh
```

Este script genera un par de llaves en `inventory/.ssh`.

Ahora debes copiar tu llave publica a los nodos a administrar:

```
$ ssh-copy-id -i inventory/.ssh/id-ansible.rsa.pub pi@k3s-master
$ ssh-copy-id -i inventory/.ssh/id-ansible.rsa.pub pi@k3s-worker1
$ ssh-copy-id -i inventory/.ssh/id-ansible.rsa.pub pi@k3s-worker2
```

El comando anterior copiara la llave pública al archivo `/home/pi/.ssh/authorized_keys` en la
máquinas del cluster.

Ahora debes modificar tu inventario para definir los parámetros de configuración correctamente:

```
$ vim inventory/hosts
```

Ahora que ya tienes configurado el inventario, puedes probar la conexión:

```
$ ansible master -m ping
$ ansible workers -m ping
```

Listo ya tienes ansible funcionando.

## Validación de playbooks

Antes de ejecutar el playbook debemos validar que la sintaxis está correcta:

```
$ ansible-playbook --syntax-check deploy-master.yml
$ ansible-playbook --syntax-check deploy-workers.yml
```

En caso de que no aparezca ningún error.

## Ejecución de playbook

**Master:**

Para desplegar k3s en el nodo maestro ejecutamos:

```
$ ansible-playbook deploy-master.yml --tags k3s_install
```

**Workers:**

Para desplegar k3s en los nodos workers ejecutamos:

```
$ ansible-playbook deploy-workers.yml --tags k3s_install
```

## Verificando el cluster

Verificando la información de la API del cluster:

```
$ kubectl cluster-info
```

Verificando la información los nodos del cluster:

```
$ kubectl get nodes -o wide
```

## Desinstalando k3s

**Master:**

Para desinstalar k3s en el nodo maestro ejecutamos:

```
$ ansible-playbook deploy-master.yml --tags k3s_uninstall
```

**Workers:**

Para desinstalar k3s en los nodos workers ejecutamos:

```
$ ansible-playbook deploy-workers.yml --tags k3s_uninstall
```

## Referencias

La siguiente es una lista de referencias externas que podemos consultar para aprender más del tema:

* [k3s](https://k3s.io/)
* [ansible](https://github.com/ansible/ansible)
