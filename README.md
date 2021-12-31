# ansible-k3s

[![CI](https://github.com/jorgearma1982/infra-home/actions/workflows/ci.yml/badge.svg)](https://github.com/jorgearma1982/infra-home/actions/workflows/ci.yml)

## Introducción

En este repositorio mantenemos bajo control de versiones los playbooks de ansible y otras herramientas para
automatizar el despliegue de un cluster Kubernetes usando `k3s` sobre maquinas `Raspberry Pi OS` (buster 10).

`k3s` es una distribución de kubernetes certificada, nos permite construir un cluster altamente disponible. Está
diseñado para cargas de trabajo Edge productivas, desatendidas, con recursos limitados, y en locaciones lejanas
(work from home) ó en artefactos IoT.

Es un sistema simplificado y seguro ya que esta empaquetado en un solo binario de <50MB que reduce las dependencias
y pasos para instalar, ejecutar y auto-actualizar un cluster de producción.

Soporta arquitecturas `ARM64` y `ARMv7`, funciona muy bien desde algo tan pequeño como una Raspberry Pi hasta en una
instancia de AWS `a1.4xlarge` con 32GB.

## Requisitos

Necesitamos cuatro máquinas, una desde donde usaremos ansible, diremos que es el nodo controlador, y las otras
máquinas serán la que controlaremos. Los nodos serán llamados así:

* `localdev`: maquina del desarrollador, ansible nodo controlador
* `k3s-master`: maquina cluster kubernetes, ansible nodo controlado
* `k3s-worker1`: maquina cluster kubernetes, ansible nodo controlado
* `k3s-worker2`: maquina cluster kubernetes, ansible nodo controlado

Los maquinas del cluster `k3s` ya deben tener instalado el sistema operativo Raspberry Pi OS 10 (buster), debe tener
configurada la interfaz WIFI conectada solo para administración (sin servidores dns ni gateway), la interfaz Ethernet
debe estar configurada con dirección IP estática, con dns y gateway. El servicio SSH debe estar configurado para
permitir las conexiones remotas. Se debe generar una contraseña para el usuario local `pi` para evitar usar la
contraseña predeterminada.

## Instalación y configuración

Debes instalar ansible localmente en la maquina nodo controlador, puede ser en Linux o MacOS siguiendo
las siguientes instrucciones:

**Linux:**

```
$ sudo apt install python3
$ pip3 install ansible yamllint pre-commit
```

**MacOS:**

```
$ brew install python3
$ pip3 install ansible yamllint pre-commit
```

Verifica que ansible está instalado:

```
$ ansible --version
```

Instala hooks pre commit:

```
$ pre-commit install
```

Ahora debes generar tus llaves RSA usando el script:

```
$ scripts/generate-ssh-keys.sh
```

Este script genera un par de llaves en `ansible/inventory/.ssh`.

**IMPORTANTE:** No debe almacenar en el repositorio git las llaves ssh ni el archivo de inventario. Almacene estos
archivos en una herramienta para gestionar secretos.

Entramos al directorio del componente ansible:

```
$ cd ansible
```

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
$ ansible-playbook --syntax-check deploy-k3s-master.yml
$ ansible-playbook --syntax-check deploy-k3s-workers.yml
```

En caso de que no aparezca ningún error.

## Ejecución de playbook

**Master:**

Para desplegar k3s en el nodo maestro ejecutamos:

```
$ ansible-playbook deploy-k3s-master.yml
```

Ahora nos conectamos al nodo `k3s-master` y obtenemos el token:

```
$ sudo cat /var/lib/rancher/k3s/server/node-token
```

**Workers:**

Editamos el inventario y agregamos las variables personalizadas para registrar los workers con el nodo maestro:

```
$ vim inventory/hosts
...
...
...
# k3s-server
k3s_server_url="k3s-master:6443"
k3s_server_token="Kstringsototototototototototote::server:secretotototote"
```

Para desplegar k3s en los nodos workers ejecutamos:

```
$ ansible-playbook deploy-k3s-workers.yml
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

## Recomendaciones seguridad

Se deben seguir las siguientes recomendaciones:

- Las secretos como llaves y credenciales se generan y almacenar en una herramienta de gestión de contraseñas.
- Los secretos entre personas se comparten solo a través medios y transmisiones cifradas.
- Los secretos necesarios para construir el proyecto se implementan como secretos a través de a herramienta de CI/CD.
- Los secretos necesarios para desplegar los servicios se implementan como secretos de ansible vault.
- Los secretos necesarios para ejecutar las aplicaciones se implementan como secretos de kubernetes.

No está de más decir, que nunca se debe hacer commit de datos sensibles hardcodeados, se rechazara cualquier PR
que no siga estas reglas, y se recomendara volver a leer las recomendaciones de arriba.

## Desinstalando k3s

Para desinstalar k3s en el nodo maestro y workers ejecutamos:

```
$ cd ansible
$ ansible-playbook uninstall-k3s.yml
```

## Workflow

Usamos los Workflows de Github Actions para automatizar las tareas para construir la infraestructura usando
ansible. En el directorio .github/workflows se encuentran los archivos .yml para cada flujo.

## Recomendaciones

Siempre recuerda hacer la validación previa y revisión de formato en los archivos de ansible. Se recomienda
usar los git hooks como pre-commit para validar los archivos ansible y aplicarles el format.

## Referencias

La siguiente es una lista de referencias externas que podemos consultar para aprender más del tema:

* [k3s](https://k3s.io/)
* [ansible](https://github.com/ansible/ansible)
