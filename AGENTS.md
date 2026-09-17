# AGENTS.md

Infraestructura casera (homelab) controlada con Ansible: despliega Pi-hole (DNS) y un cluster K3s
sobre Raspberry Pi OS, más los manifiestos Kubernetes base. Sin aplicación propia: el "código"
son playbooks, roles y YAML. Documentación de referencia en `docs/` (deploy-k3s-cluster.md,
install-raspberry-pi-os.md). Idioma del repo: español.

## Dev environment

Toolchain Python vía pip, versiones pineadas en `requirements.txt` (ansible 11 / ansible-core 2.18,
ansible-lint, yamllint, pre-commit, kubernetes):

    pip3 install -r requirements.txt
    pre-commit install

SSH: `scripts/build-ssh-keys.sh` genera llaves ed25519 en `ansible/inventory/.ssh` (gitignored).
Luego `scripts/deploy-ssh-keys.sh` (pide contraseña con `-k -K`) y `scripts/test-ssh-keys.sh`
(=`ansible all -m ping`).

## Comandos

Todo playbook se ejecuta desde `ansible/` (ahí vive `ansible.cfg` con inventory
`inventory/hosts.yml` y `roles_path = roles`):

    cd ansible
    ansible-playbook --syntax-check deploy-net.yml
    ansible-lint deploy-net.yml
    ansible-playbook deploy-net.yml            # requiere inventario y llaves locales

Validación completa (lo que corre CI):

    pre-commit run --all-files                # yamllint --strict + ansible-lint + k8svalidate + detect-secrets
    yamllint --strict -f parsable .           # desde la raíz del repo

CI (`.github/workflows/ci.yml`, solo en PRs a main) hace: yamllint strict, `--syntax-check` y
`ansible-lint` de estos 5 playbooks: deploy-net, deploy-nas, deploy-k3s-master, deploy-k3s-workers,
deploy-k3s-gateway. Un playbook nuevo fuera de esa lista no se valida en CI — agregar el step.

## Layout y convenciones

- `ansible/*.yml` — playbooks por propósito:
  - `deploy-<cosa>.yml`: deploy-net, deploy-nas, deploy-k3s-master/workers/gateway,
    deploy-k3s-argocd, deploy-k3s-argocd-apps, deploy-ssh-keys.
  - `deploy-local-*.yml`: corren en localhost (kubeconfig, argocd-cli, ca-cert).
  - Otros: `reboot-k3s-cluster.yml`, `uninstall-k3s.yml`.
- `ansible/roles/<rol>/` — estructura estándar: `tasks/main.yml`, `meta/main.yml`,
  `defaults/main.yml`, `handlers/main.yml`, `templates/*.j2`, `README.md` por rol.
  Roles existentes (usar antes que crear): docker, pi-hole, ntp-server/client, cgroups,
  k3s-server/agent/gateway/argocd/argocd-apps, nfs-client, usb-storage, samba-server, ssh-server,
  general-settings, disable-swapfile, shell-tools, k8s-tools, iptables-legacy.
- Playbooks: `hosts:` apunta a grupos (`net_servers`, etc.), `become: true`, roles en orden;
  `pre_tasks`/`post_tasks` para apt update/autoclean. Tasks con FQCN (`ansible.builtin.apt`).
- `kubernetes/{prod,uat,test}/` — un `namespace.yml` por entorno + un directorio por app con
  `deployment.yml`, `service.yml`, `ingress.yml`, `serviceaccount.yml` (referencia: `whoami`).
- Nombres de tasks en español, formato `Despliega | <servicio>` en el name del play.

## Pitfalls

- `inventory/hosts.yml`, `group_vars/`, `host_vars/`, llaves y certificados están en `.gitignore`
  — el checkout no trae inventario ni variables de entorno. Sin esos archivos locales los
  playbooks no corren (solo `--syntax-check` y lint funcionan sin ellos).
- Nunca commitear secretos: llaves (`.ssh/`), kubeconfig, certs, credenciales. Van en gestor de
  contraseñas / ansible-vault / secrets de K8s según la capa (ver "Recomendaciones de seguridad"
  del README). detect-secrets corre en pre-commit.
- `ansible.cfg` fija `interpreter_python = /usr/bin/python3` — en macOS requiere Command Line
  Tools instalados.
- yamllint `--strict` (level warning activo): línea >180, octales implícitos y truthy en keys
  fallan el hook.
- ansible-lint tiene skips intencionales en `.ansible-lint` (command-instead-of-module,
  risky-shell-pipe, command-instead-of-shell) — no "corregir" tasks shell/command solo por el
  lint.
