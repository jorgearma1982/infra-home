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

* Preparar máquinas con `Raspberry Pi OS 12` o `Ubuntu Server` para rol de nodos kubernetes
* Desplegar cluster kubernetes en nodo maestro y workers usando `K3s`
* Configurar kubectl y helm para administrar servicios y aplicaciones
* Desplegar `MetalLB`, `NGINX` Ingress, `cert-manager` y `external-dns` para acceso externo al cluster

## Requisitos

Necesitamos cuatro máquinas, una desde donde usaremos ansible, diremos que es el nodo controlador, y las otras
máquinas serán la que controlaremos. La topología de ejemplo usa tres Raspberry Pi, pero los playbooks funcionan
igual con máquinas virtuales Ubuntu Server. Los nodos serán llamados así:

* `localdev`: maquina del desarrollador, ansible nodo controlador, linux/macos
* `k3s-master`: maquina cluster kubernetes, ansible nodo controlado, raspberry pi 4B+ 4GB
* `k3s-worker1`: maquina cluster kubernetes, ansible nodo controlado, raspberry pi 4B+ 4GB
* `k3s-worker2`: maquina cluster kubernetes, ansible nodo controlado, raspberry pi 4B+ 4GB

Los maquinas del cluster `K3s` ya deben tener instalado el sistema operativo (`Raspberry Pi OS 12` bookworm para
las Raspberry Pi, `Ubuntu Server` para máquinas virtuales), debe tener configurada la interfaz Ethernet con
dirección IP estática o DHCP reservado, con DNS y gateway. El servicio SSH debe estar configurado para permitir
las conexiones remotas, con un usuario con acceso sudo (el usuario por defecto `pi` en Raspberry Pi OS o el
usuario creado durante la instalación de Ubuntu Server).

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

Antes de comenzar, en el nodo controlador debe estar instalada la toolchain de ansible siguiendo el `README.md`
del repositorio: `pip3 install -r requirements.txt` y las colecciones de Ansible Galaxy que usan los roles:

```shell
ansible-galaxy collection install -r requirements.yml
```

> [!WARNING]
> `kubernetes.core` está pineada en `2.4.0` en `requirements.yml`: a partir de la `3.0.0` la colección exige
> la librería Python `kubernetes >= 24.2.0` y los nodos traen `22.6` desde apt (`python3-kubernetes`).

Entramos al directorio del componente ansible:

```shell
cd ansible
```

Ahora debes copiar tu llave publica a los nodos a administrar. Desde la raíz del repositorio, este incluye
scripts para generar las llaves y desplegarlas:

```shell
scripts/build-ssh-keys.sh
scripts/deploy-ssh-keys.sh
scripts/test-ssh-keys.sh
```

Alternativamente puedes copiar la llave pública manualmente:

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

En caso de que no aparezca ningún error, la sintaxis es correcta y podemos continuar.

## Ejecución de playbooks

**Master:**

Para desplegar K3s en el nodo maestro ejecutamos:

```shell
ansible-playbook deploy-k3s-master.yml
```

Para desplegar la configuración de los clusters en local:

```shell
ansible-playbook deploy-local-kubeconfig.yml
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

Como se pude ver, el cluster está corriendo en `localhost` en el puerto `6443`. Con `sudo` porque aún no se ha
desplegado el kubeconfig del usuario; después de ejecutar `deploy-local-kubeconfig.yml` los comandos `kubectl`
funcionan directamente sin `sudo`.

Mostremos la salud del cluster:

```shell
$ kubectl get --raw '/healthz?verbose'
[+]ping ok
[+]log ok
[+]etcd ok
[+]poststarthook/start-apiserver-admission-initializer ok
[+]poststarthook/generic-apiserver-start-informers ok
[+]poststarthook/priority-and-fairness-config-consumer ok
[+]poststarthook/priority-and-fairness-filter ok
[+]poststarthook/storage-object-count-tracker-hook ok
[+]poststarthook/start-apiextensions-informers ok
[+]poststarthook/start-apiextensions-controllers ok
[+]poststarthook/crd-informer-synced ok
[+]poststarthook/start-system-namespaces-controller ok
[+]poststarthook/start-cluster-authentication-info-controller ok
[+]poststarthook/start-kube-apiserver-identity-lease-controller ok
[+]poststarthook/start-kube-apiserver-identity-lease-garbage-collector ok
[+]poststarthook/start-legacy-token-tracking-controller ok
[+]poststarthook/start-service-ip-repair-controllers ok
[+]poststarthook/rbac/bootstrap-roles ok
[+]poststarthook/scheduling/bootstrap-system-priority-classes ok
[+]poststarthook/priority-and-fairness-config-producer ok
[+]poststarthook/bootstrap-controller ok
[+]poststarthook/aggregator-reload-proxy-client-cert ok
[+]poststarthook/start-kube-aggregator-informers ok
[+]poststarthook/apiservice-status-local-available-controller ok
[+]poststarthook/apiservice-status-remote-available-controller ok
[+]poststarthook/apiservice-registration-controller ok
[+]poststarthook/apiservice-discovery-controller ok
[+]poststarthook/kube-apiserver-autoregistration ok
[+]autoregister-completion ok
[+]poststarthook/apiservice-openapi-controller ok
[+]poststarthook/apiservice-openapiv3-controller ok
healthz check passed
```

Verificando la información los nodos del cluster:

```shell
$ kubectl get nodes -o wide
NAME        STATUS ROLES                AGE VERSION      INTERNAL-IP     EXTERNAL-IP OS-IMAGE                       KERNEL-VERSION CONTAINER-RUNTIME
k3s-master  Ready  control-plane,master 17m v1.36.4+k3s1 192.168.101.131 <none>      Debian GNU/Linux 12 (bookworm) 6.12.109-v8+   containerd://2.3.4-k3s1.36
k3s-worker1 Ready  worker               17m v1.36.4+k3s1 192.168.101.129 <none>      Debian GNU/Linux 12 (bookworm) 6.12.109-v8+   containerd://2.3.4-k3s1.36
k3s-worker2 Ready  worker               17m v1.36.4+k3s1 192.168.101.127 <none>      Debian GNU/Linux 12 (bookworm) 6.12.109-v8+   containerd://2.3.4-k3s1.36
```

Como criterio de aceptación del deploy, todos los pods del cluster deben estar en estado `Running` y `Ready`
(la columna `READY` debe mostrar `n/n`):

```shell
$ kubectl get pods -A
NAMESPACE      NAME                                       READY STATUS  RESTARTS AGE
kube-system    coredns-54996dc9b4-f2tpr                   1/1   Running 0       17m
kube-system    local-path-provisioner-77b9867795-lg5l2    1/1   Running 0       17m
kube-system    metrics-server-6dc596dfb8-9tmh8            1/1   Running 0       17m
```

> [!IMPORTANT]
> **Después de cada rebuild del cluster**, ejecutar `deploy-local-ca-cert.yml -K` para redistribuir las nuevas CAs raíz de cert-manager a los almacenes de confianza del controlador. Sin este paso, los certificados TLS de los servicios (ArgoCD, Ingress, etc.) fallarán con error SSL en máquinas que no confían en la nueva CA raíz.

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

Para dar acceso a los servicios del cluster a usuarios externos, el playbook `deploy-k3s-gateway.yml` despliega
cuatro componentes:

* `MetalLB` en modo `Layer2` para el balanceador de cargas, al que se le asigna un rango de direcciones IP
  privadas sobre las cuales balanceará el tráfico externo hacia el cluster.
* `NGINX Ingress` como controlador para la capa HTTP: rutas de acceso a los servicios web, terminación TLS,
  caché y demás funcionalidades de Nginx.
* `cert-manager` con un `ClusterIssuer` de CA raíz propia para emitir certificados internos.
* `external-dns` integrado con un servidor DNS BIND mediante RFC2136, que crea automáticamente los registros
  DNS de los servicios expuestos.

> [!WARNING]
> `external-dns` requiere un servidor DNS BIND con una zona autoritativa y una llave TSIG que permita
> actualizaciones dinámicas. Las variables se configuran en `roles/k3s-gateway/defaults/main.yml`:
> `bind_server_ip`, `bind_zone_name`, `bind_tsig_keyname`, `bind_tsig_keysecret` y `bind_tsig_secretname`.
> El secret con la llave TSIG nunca se versiona en el repositorio.

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
* [Metallb](https://metallb.io)
* [Ingress nginx](https://github.com/kubernetes/ingress-nginx)
