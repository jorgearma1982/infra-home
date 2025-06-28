# ansible-k3s

## Introducción

`K3s` es una distribución de kubernetes certificada, nos permite construir un cluster altamente disponible.
Está diseñado para cargas de trabajo Edge productivas, desatendidas, con recursos limitados, y en locaciones
lejanas (work from home) ó en artefactos IoT.

Es un sistema simplificado y seguro ya que esta empaquetado en un solo binario de <50MB que reduce las dependencias
y pasos para instalar, ejecutar y auto-actualizar un cluster de producción.

Soporta arquitecturas `x86_64`, `ARM64` y `ARMv7`, funciona muy bien desde algo tan pequeño como una Raspberry Pi
hasta en una instancia de AWS `a1.4xlarge` con 32GB.

### Objetivos

Necesitamos implementar un pequeño cluster kubernetes para hospedar algunas aplicaciones web para uso privado,
los objetivos principales son:

* Preparar máquinas con `Raspberry OS 12` para rol de nodos kubernetes
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

Los maquinas del cluster `K3s` ya deben tener instalado el sistema operativo Raspberry Pi OS 12 (bookworm), debe tener
configurada la interfaz WIFI conectada solo para administración (sin servidores DNS ni gateway), la interfaz Ethernet
debe estar configurada con dirección IP estática, con DNS y gateway. El servicio SSH debe estar configurado para
permitir las conexiones remotas. Se debe generar una contraseña para el usuario local `pi` para evitar usar la
contraseña predeterminada.

Además de las direcciones IP privadas que usará cada servidor, necesitaremos un rango de direcciones IP privadas
dedicadas para el balanceador de cargas, aquí usaremos un rango de 8 direcciones IP en una subred clase C.

En la siguiente tabla se muestran las configuraciones de IP para los nodos y el balanceador de cargas:

| Nodo        | Dirección IP        | Mascara subred | Gateway         | DNS           |
|-------------|---------------------|----------------|-----------------|---------------|
| k3s-master  | 192.168.101.131     | 255.255.255.0  | 192.168.101.254 | 192.168.101.2 |
| k3s-worker1 | 192.168.101.129     | 255.255.255.0  | 192.168.101.254 | 192.168.101.2 |
| k3s-worker2 | 192.168.101.127     | 255.255.255.0  | 192.168.101.254 | 192.168.101.2 |
| k3s-lb-pool | 192.168.101.150-157 | 255.255.255.0  | 192.168.101.254 | 192.168.101.2 |

Las maquinas del cluster deben ser capaces de comunicarse entre si mismas por medio de nombres DNS, por lo tanto
todas las maquinas deben usar servidores DNS comunes que tengan hospedada una zona autoritativa con los registros
de los nombres de las maquinas y sus respectivas direcciones IP, de preferencia también poner resolución reversa
para acelerar las consultas de nombres y direcciones.

**IMPORTANTE:** En caso de no tener un servicio DNS se tendrá que poner el mapa de direcciones y nombres local en
cada maquina usando el archivo `/etc/hosts`.

## Instalación y configuración

Entramos al directorio del componente ansible:

```shell
cd ansible
```

Ahora debes copiar tu llave publica a los nodos a administrar:

```shell
ssh-copy-id -i inventory/.ssh/id_ansible_ed25519.pub pi@k3s-master
ssh-copy-id -i inventory/.ssh/id_ansible_ed25519.pub pi@k3s-worker1
ssh-copy-id -i inventory/.ssh/id_ansible_ed25519.pub pi@k3s-worker2
```

El comando anterior copiara la llave pública al archivo `/home/pi/.ssh/authorized_keys` en la
máquinas del cluster.

Ahora debes modificar tu inventario para definir los parámetros de configuración correctamente:

```shell
vim inventory/hosts.yml
```

Añadimos el siguiente bloque para definir dos grupos de nodos:

```yaml
all:
  children:
    master:
      hosts:
        k3s-master.hq.kronops.io:
          ansible_host: 192.168.101.131
          ansible_user: pi
    workers:
      hosts:
        k3s-worker1.hq.kronops.io:
          ansible_host: 192.168.101.129
          ansible_user: pi
        k3s-worker2.hq.kronops.io:
          ansible_host: 192.168.101.127
          ansible_user: pi
```

Ahora que ya tienes configurado el inventario, puedes probar la conexión:

```shell
ansible master -m ping
ansible workers -m ping
```

Listo ya tienes ansible funcionando, hagamos unas pruebas para ejecutar comandos en modo `ad-hoc`.

Mostremos información de los nodos:

```shell
ansible -m shell -a \
 'uname -a && \
 lsb_release -d && \
 cat /proc/cpuinfo | grep "Revision\|Model" &&\
 cat /proc/meminfo | grep MemTotal && \
 lscpu | grep "Architecture\|Model name\|CPU max MHz"' \
 master,workers
```

## Validación de playbooks

Antes de ejecutar el playbook debemos validar que la sintaxis está correcta:

```shell
ansible-playbook --syntax-check deploy-k3s-master.yml
ansible-playbook --syntax-check deploy-k3s-workers.yml
ansible-playbook --syntax-check deploy-k3s-gateway.yml
```

En caso de que no aparezca ningún error.

## Ejecución de playbooks

**Master:**

Para desplegar K3s en el nodo maestro ejecutamos:

```shell
ansible-playbook deploy-k3s-master.yml
```

**Workers:**

Para desplegar K3s en los nodos workers ejecutamos:

```shell
ansible-playbook deploy-k3s-workers.yml
```

## Verificando el cluster

Verificando la información de la API del cluster:

```shell
$ sudo kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Verificando la información los nodos del cluster:

```shell
$ sudo kubectl get nodes -o wide
NAME        STATUS ROLES                AGE VERSION      INTERNAL-IP     EXTERNAL-IP OS-IMAGE                       KERNEL-VERSION CONTAINER-RUNTIME
k3s-master  Ready  control-plane,master 17m v1.32.5+k3s1 192.168.101.131 <none>      Debian GNU/Linux 12 (bookworm) 6.12.33-v8+    containerd://2.0.5-k3s1.32
k3s-worker1 Ready  worker               17m v1.32.5+k3s1 192.168.101.129 <none>      Debian GNU/Linux 12 (bookworm) 6.12.33-v8+    containerd://2.0.5-k3s1.32
k3s-worker2 Ready  worker               17m v1.32.5+k3s1 192.168.101.127 <none>      Debian GNU/Linux 12 (bookworm) 6.12.33-v8+    containerd://2.0.5-k3s1.32
```

## Probando despliegue sencillo

Ahora desplegamos nginx simple:

```shell
sudo kubectl apply -f https://k8s.io/examples/controllers/nginx-deployment.yaml
```

Escalamos el despliegue a 20 replicas:

```shell
sudo kubectl scale --replicas=20 deployment/nginx-deployment
```

Listamos los pods del despliegue:

```shell
sudo kubectl get pods -o wide
```

Intenta escalar de 40 en 40 hasta llegar a 240, más no se puede por el limite de IPs para los pods.

Eliminamos el despliegue:

```shell
sudo kubectl delete -f https://k8s.io/examples/controllers/nginx-deployment.yaml
```

## Despliegue servicios de red externa

Para dar acceso a los servicios del cluster a usuarios externos, implementaremos un balanceador de cargas en nuestro
cluster baremetal, usaremos MetalLB, el cual nos permite trabajar con protocolos de enrutamiento estandar.

Configuraremos MetalLB en modo `Layer2` y le asignaremos un rango de direcciones IP privadas sobre las cuales
balancearemos el tráfico externo hacia el cluster.

Para gestionar la capa HTTP implementaremos un servicio controlador Ingress, este nos permite definir rutas de acceso
a los servicios web dentro del cluster, podemos implementar seguridad TLS haciendo de terminador SSL o TLS, es posible
implementar caché para acelerar el acceso a objetos estáticos, listas blancas y muchas otras funcionalidades que
provee Nginx.

```shell
ansible-playbook deploy-k3s-gateway.yml
```

## Desinstalando k3s

Para desinstalar K3s en el nodo maestro y workers ejecutamos:

```shell
cd ansible
ansible-playbook uninstall-k3s.yml
```

## Referencias

La siguiente es una lista de referencias externas que podemos consultar para aprender más del tema:

* [Kubernetes](https://kubernetes.io/es/)
* [Raspberry Pi](https://www.raspberrypi.org/)
* [K3s](https://k3s.io/)
* [Ansible](https://github.com/ansible/ansible)
* [Metallb](https://metallb.universe.tf/)
* [Ingress nginx](https://github.com/kubernetes/ingress-nginx)
