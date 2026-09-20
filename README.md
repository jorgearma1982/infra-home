# infra-home

[![CI](https://github.com/jorgearma1982/infra-home/actions/workflows/ci.yml/badge.svg)](https://github.com/jorgearma1982/infra-home/actions/workflows/ci.yml)

En este repositorio mantenemos bajo control de versiones los playbooks de ansible y otras herramientas para
automatizar el despliegue de diferentes servicios en la red local, por ejemplo:

* Pi-hole: DNS con listas negras sobre máquinas `Raspberry Pi OS`.
* K3s: Cluster Kubernetes sobre máquinas `Raspberry Pi OS`.
* Argo CD: GitOps para las aplicaciones del cluster.

## Instalación y configuración

Instalamos ansible localmente en la maquina nodo controlador:

**Linux:**

```shell
sudo apt install python3
pip3 install -r requirements.txt
```

**MacOS:**

```shell
brew install python3
pip3 install -r requirements.txt
```

El archivo `requirements.txt` mantiene las versiones fijas de las herramientas: ansible, ansible-lint,
yamllint, pre-commit y el cliente de kubernetes.

Instala las colecciones de Ansible Galaxy:

```shell
ansible-galaxy collection install -r ansible/requirements.yml
```

> [!WARNING]
> `kubernetes.core` está pineada en `2.4.0`: a partir de la `3.0.0` la colección exige la librería
> Python `kubernetes >= 24.2.0` y los nodos traen `22.6` desde apt (`python3-kubernetes`). Cuando
> la librería se actualice en los nodos, sube el pin en `ansible/requirements.yml`.

> [!NOTE]
> El canal de k3s está configurado en `stable` (actualmente v1.36.x) en `roles/k3s-server/defaults/main.yml`.

> [!IMPORTANT]
> **Después de cada rebuild del cluster**, ejecutar `deploy-local-ca-cert.yml -K` para redistribuir las nuevas CAs raíz de cert-manager a los almacenes de confianza del controlador. Sin este paso, los certificados TLS de los servicios (ArgoCD, Ingress, etc.) fallarán con error SSL en máquinas que no confían en la nueva CA raíz.

Instala hooks pre commit:

```shell
pre-commit install
```

Ahora debes generar tus llaves ssh usando el script:

```shell
scripts/build-ssh-keys.sh
```

Este script genera un par de llaves en `ansible/inventory/.ssh`.

**IMPORTANTE:** No debe almacenar en el repositorio git las llaves ssh ni el archivo de inventario. El
inventario (`ansible/inventory/hosts.yml`), `group_vars/`, `host_vars/`, llaves y certificados están
ignorados por git y no vienen en el checkout: se consiguen con el equipo y se guardan en una herramienta
para gestión de secretos.

Despliega llave ssh de ansible a servidores:

```shell
scripts/deploy-ssh-keys.sh
```

Por último hacemos una prueba para verificar que las llaves funcionan:

```shell
scripts/test-ssh-keys.sh
```

## Playbooks

Todos los playbooks se ejecutan desde el directorio `ansible/`, donde vive `ansible.cfg` con el inventario
(`inventory/hosts.yml`) y el path de roles.

| Playbook | Hosts | Propósito |
| --- | --- | --- |
| `deploy-net.yml` | `net_servers` | Pi-hole DNS, NTP server, Docker, hardening base |
| `deploy-nas.yml` | `nas` | NAS: samba, nfs, usb-storage |
| `deploy-k3s-master.yml` | `master` | Prepara e instala el nodo maestro K3s |
| `deploy-k3s-workers.yml` | `master` + `workers` | Obtiene token del master y une workers al cluster |
| `deploy-k3s-gateway.yml` | `master` | MetalLB, cert-manager, ingress-nginx, external-dns |
| `deploy-k3s-argocd.yml` | `k3s-devops.hq.kronops.io` | Instala Argo CD en el cluster |
| `deploy-k3s-argocd-apps.yml` | `k3s-devops.hq.kronops.io` | Registra aplicaciones en Argo CD |
| `deploy-local-kubeconfig.yml` | `localhost` | Genera kubeconfig del cluster en `~/.kube/config` |
| `deploy-local-argocd-cli.yml` | `localhost` | Instala CLI de Argo CD y registra clusters |
| `deploy-local-ca-cert.yml` | `localhost` | Instala el certificado raíz local en el controlador (Linux y macOS) |
| `reboot-k3s-cluster.yml` | `master`, `workers` | Reboot serial (1 a la vez) del cluster |
| `uninstall-k3s.yml` | `master`, `workers` | Desinstala K3s de todos los nodos |

Ejemplo:

```shell
cd ansible
ansible-playbook deploy-net.yml
```

La guía completa del despliegue del cluster, paso a paso y con verificaciones, vive en
[docs/deploy-k3s-cluster.md](docs/deploy-k3s-cluster.md).

## Manifiestos Kubernetes

El directorio `kubernetes/` contiene los manifiestos base por entorno (`prod`, `uat`, `test`): cada
entorno tiene su `namespace.yml` y un directorio por aplicación con `deployment.yml`, `service.yml`,
`ingress.yml` y `serviceaccount.yml`. La app `whoami` sirve como referencia. Estos manifiestos los
consume Argo CD como fuente GitOps.

## Workflow

Usamos los Workflows de Github Actions para automatizar las tareas para construir la infraestructura usando
ansible. En el directorio .github/workflows se encuentran los archivos .yml para cada flujo.

El flujo de CI (`.github/workflows/ci.yml`) corre en cada PR a `main` y valida:

* Sintaxis YAML de todo el repo con `yamllint --strict`.
* `ansible-playbook --syntax-check` de los playbooks: deploy-net, deploy-nas, deploy-k3s-master,
  deploy-k3s-workers y deploy-k3s-gateway.
* `ansible-lint` sobre esos mismos playbooks.

Si agregas un playbook nuevo, agrégalo también como step de CI.

## Recomendaciones de calidad

Siempre recuerda hacer la validación previa y revisión de formato en los archivos de ansible usando `yamllint` para
validar la sintaxis de los archivos `.yaml|.yml` y `ansible-lint` para validar las mejores prácticas. Se recomienda
usar los git hooks como pre-commit para validar los archivos ansible y aplicarles el format.

Para correr manualmente `pre-commit` con todos los hooks definidos ejecutar:

```shell
pre-commit run --all-files
```

## Recomendaciones de seguridad

Se deben seguir las siguientes recomendaciones:

* Las secretos como llaves y credenciales se generan y almacenar en una herramienta de gestión de contraseñas.
* Los secretos entre personas se comparten solo a través medios y transmisiones cifradas.
* Los secretos necesarios para construir el proyecto se implementan como secretos a través de a herramienta de CI/CD.
* Los secretos necesarios para desplegar los servicios se implementan como secretos de ansible vault.
* Los secretos necesarios para ejecutar las aplicaciones se implementan como secretos de kubernetes.

No está de más decir, que nunca se debe hacer commit de datos sensibles hard codeados, se rechazara cualquier PR
que no siga estas reglas, y se recomendara volver a leer las recomendaciones de arriba.

## Referencias

La siguiente es una lista de referencias externas que podemos consultar para aprender más del tema:

* [Ansible](https://github.com/ansible/ansible)
