# ansible-k3s

## Introducción

`K3s` es una distribución de kubernetes certificada, nos permite construir un cluster altamente disponible. Está
diseñado para cargas de trabajo Edge productivas, desatendidas, con recursos limitados, y en locaciones lejanas
(work from home) ó en artefactos IoT.

Es un sistema simplificado y seguro ya que esta empaquetado en un solo binario de <50MB que reduce las dependencias
y pasos para instalar, ejecutar y auto-actualizar un cluster de producción.

Soporta arquitecturas `ARM64` y `ARMv7`, funciona muy bien desde algo tan pequeño como una Raspberry Pi hasta en una
instancia de AWS `a1.4xlarge` con 32GB.

### Objetivos

Necesitamos implementar un pequeño cluster kubernetes para hospedar algunas aplicaciones web para uso privado,
los objetivos principales son:

* Preparar máquinas con `Raspberry OS 10` para rol de nodos kubernetes
* Desplegar cluster kubernetes en nodo maestro y workers usando `K3s`
* Configurar kubectl y helm para administrar servicios y aplicaciones
* Desplegar `MetalLB` y `NGINX` Ingress para acceso externo al cluster

## Requisitos

Necesitamos cuatro máquinas, una desde donde usaremos ansible, diremos que es el nodo controlador, y las otras
máquinas serán la que controlaremos. Los nodos serán llamados así:

* `localdev`: maquina del desarrollador, ansible nodo controlador, linux/macos
* `k3s-master`: maquina cluster kubernetes, ansible nodo controlado, raspberry pi 4B+ 4GB
* `k3s-worker1`: maquina cluster kubernetes, ansible nodo controlado, raspberry pi 4B+ 4GB
* `k3s-worker2`: maquina cluster kubernetes, ansible nodo controlado, raspberry pi 4B+ 4GB

Los maquinas del cluster `K3s` ya deben tener instalado el sistema operativo Raspberry Pi OS 10 (buster), debe tener
configurada la interfaz WIFI conectada solo para administración (sin servidores DNS ni gateway), la interfaz Ethernet
debe estar configurada con dirección IP estática, con DNS y gateway. El servicio SSH debe estar configurado para
permitir las conexiones remotas. Se debe generar una contraseña para el usuario local `pi` para evitar usar la
contraseña predeterminada.

Además de las direcciones IP privadas que usará cada servidor, necesitaremos un rango de direcciones IP privadas
dedicadas para el balanceador de cargas, aquí usaremos un rango de 10 direcciones IP en una subred clase C.

Las maquinas del cluster deben ser capaces de comunicarse entre si mismas por medio de nombres DNS, por lo tanto
todas las maquinas deben usar servidores DNS comunes que tengan hospedada una zona autoritativa con los registros
de los nombres de las maquinas y sus respectivas direcciones IP, de preferencia también poner resolución reversa.

**IMPORTANTE:** En caso de no tener un servicio DNS se tendrá que poner el mapa de direcciones y nombres local en
cada maquina usando el archivo `/etc/hosts`.

## Instalación y configuración

Entramos al directorio del componente ansible:

```
$ cd ansible
```

Ahora debes copiar tu llave publica a los nodos a administrar:

```
$ ssh-copy-id -i inventory/.ssh/id_ansible_ed25519.pub pi@k3s-master
$ ssh-copy-id -i inventory/.ssh/id_ansible_ed25519.pub pi@k3s-worker1
$ ssh-copy-id -i inventory/.ssh/id_ansible_ed25519.pub pi@k3s-worker2
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
$ ansible-playbook --syntax-check deploy-k3s-helm.yml
```

En caso de que no aparezca ningún error.

## Ejecución de playbook

**Master:**

Para desplegar K3s en el nodo maestro ejecutamos:

```
$ ansible-playbook deploy-k3s-master.yml
```

**Workers:**

Para desplegar K3s en los nodos workers ejecutamos:

```
$ ansible-playbook deploy-k3s-workers.yml
```

**Localdev:**

Limpiamos archivo de token de servidor maestro:

```
$ rm /tmp/k3s-master-node-token
```

## Verificando el cluster

Verificando la información de la API del cluster:

```
$ sudo kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Verificando la información los nodos del cluster:

```
$ sudo kubectl get nodes -o wide
NAME          STATUS   ROLES                  AGE     VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
k3s-worker1   Ready    worker                 4m54s   v1.22.5+k3s1   192.168.114.16   <none>        Raspbian GNU/Linux 10 (buster)   5.10.63-v7l+     containerd://1.5.8-k3s1
k3s-worker2   Ready    worker                 3m54s   v1.22.5+k3s1   192.168.114.17   <none>        Raspbian GNU/Linux 10 (buster)   5.10.63-v7l+     containerd://1.5.8-k3s1
k3s-master    Ready    control-plane,master   30m     v1.22.5+k3s1   192.168.114.15   <none>        Raspbian GNU/Linux 10 (buster)   5.10.63-v7l+     containerd://1.5.8-k3s1
```

## Configurando servicios de red

Para dar acceso a los servicios del cluster a usuarios externos, implementaremos un balanceador de cargas en nuestro
cluster baremetal, usaremos MetalLB, el cual nos permite trabajar con protocolos de enrutamiento estandar.

Configuraremos MetalLB en modo `Layer2` y le asignaremos un rango de direcciones IP privadas sobre las cuales
balancearemos el tráfico externo hacia el cluster.

Para gestionar la capa HTTP implementaremos un servicio controlador Ingress, este nos permite definir rutas de acceso
a los servicios web dentro del cluster, podemos implementar seguridad TLS haciendo de terminador SSL o TLS, es posible
implementar caché para acelerar el acceso a objetos estáticos, listas blancas y muchas otras funcionalidades que
provee Nginx.

```
$ ansible-playbook deploy-k3s-helm.yml
```

## Desinstalando k3s

Para desinstalar K3s en el nodo maestro y workers ejecutamos:

```
$ cd ansible
$ ansible-playbook uninstall-k3s.yml
```

## Referencias

La siguiente es una lista de referencias externas que podemos consultar para aprender más del tema:

* [Kubernetes](https://kubernetes.io/es/)
* [Raspberry Pi](https://www.raspberrypi.org/)
* [K3s](https://k3s.io/)
* [Ansible](https://github.com/ansible/ansible)
* [Metallb](https://metallb.universe.tf/)
* [Ingress nginx](https://github.com/kubernetes/ingress-nginx)
