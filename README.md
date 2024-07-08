# infra-home

[![CI](https://github.com/jorgearma1982/infra-home/actions/workflows/ci.yml/badge.svg)](https://github.com/jorgearma1982/infra-home/actions/workflows/ci.yml)

En este repositorio mantenemos bajo control de versiones los playbooks de ansible y otras herramientas para
automatizar el despliegue diferentes servicios en la red local, por ejemplo:

* Pi-hole: DNS con listas negras sobre máquinas `Raspberry Pi OS`.
* K3s: Cluster Kubernetes sobre maquinas `Raspberry Pi OS`.

## Instalación y configuración

Instalamos ansible localmente en la maquina nodo controlador:

**Linux:**

```shell
sudo apt install python3
pip3 install ansible yamllint ansible-lint pre-commit
```

**MacOS:**

```shell
brew install python3
pip3 install ansible yamllint ansible-lint pre-commit
```

Verifica que ansible está instalado:

```shell
ansible --version
```

Verifica que ansible-lint está instalado:

```shell
ansible-lint --version
```

Instala hooks pre commit:

```shell
pre-commit install
```

Ahora debes generar tus llaves ssh usando el script:

```shell
scripts/build-ssh-keys.sh
```

Este script genera un par de llaves en `ansible/inventory/.ssh`.

**IMPORTANTE:** No debe almacenar en el repositorio git las llaves ssh ni el archivo de inventario. Almacene estos
archivos en una herramienta para gestionar secretos.

Despliega llave ssh de ansible a servidores:

```shell
scripts/deploy-ssh-keys.sh
```

Por último hacemos una prueba para verificar que las llaves funcionan:

```shell
scripts/test-ssh-keys.sh
```

## Workflow

Usamos los Workflows de Github Actions para automatizar las tareas para construir la infraestructura usando
ansible. En el directorio .github/workflows se encuentran los archivos .yml para cada flujo.

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
