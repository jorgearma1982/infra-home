k3s-argocd-apps
==============

Tasks to register Argo CD Application resources for the whoami demo app across test, uat, and prod clusters.

Requirements
------------

- Argo CD installed and accessible (via `deploy-k3s-argocd.yml`)
- Target clusters registered in Argo CD (via `deploy-local-argocd-cli.yml`)
- `kubectl` configured with contexts for target clusters

Role Variables
--------------

None currently. Applications are defined as static manifests in `files/`.

Dependencies
------------

This role depends on k3s-master (Argo CD must be running).

What it does
------------

Registers Argo CD Application resources (copy manifest to /tmp + `kubectl apply` per app):

**whoami demo (test, uat, prod):**

1. **Namespace Applications** (`whoami-namespace-{test,uat,prod}`):
   - Creates the `whoami` namespace in each target cluster
   - Source: `kubernetes/{test,uat,prod}/namespace.yml`
   - Auto-sync enabled (prune + selfHeal) only for test

2. **App Applications** (`whoami-app-{test,uat,prod}`):
   - Deploys the whoami demo app (Deployment, Service, Ingress, ServiceAccount)
   - Source: `kubernetes/{test,uat,prod}/whoami/`
   - Auto-sync enabled (prune + selfHeal) only for test
   - Test cluster uses `traefik/whoami:v1.11.0` image

**LGTM observability stack (o11y cluster, namespace `monitoring`):**

- **`lgtm-{grafana,loki,tempo,mimir}`** — Helm charts from `https://grafana.github.io/helm-charts`
  with inline values, pinned versions and auto-sync (prune + selfHeal).
  Runbook: `docs/o11y-lgtm-runbook.md`
- **`api-gateway-o11y`** — git source by path (`kubernetes/o11y/api-gateway-o11y/`): the
  TLS ingresses for grafana/loki/tempo/mimir (`*.hq.kronops.io`). Ingresses live in git as
  flat manifests, NOT in the helm values of the charts.

Target clusters (defined in Application `spec.destination.server`):
- test: `https://10.101.165.11:6443` (k3s-test)
- uat: `https://10.101.165.12:6443` (k3s-uat)
- prod: `https://10.101.165.13:6443` (k3s-prod)
- o11y: `https://10.101.165.15:6443` (k3s-o11y)

All Applications belong to the `platform` Argo CD project.

Example Playbook
----------------

```yaml
- hosts: k3s-devops.hq.kronops.io
  become: true
  roles:
     - k3s-argocd-apps
```

Execution
---------

```bash
cd ansible
ansible-playbook deploy-k3s-argocd-apps.yml -K
```

Runs on the devops cluster (`k3s-devops.hq.kronops.io`) which has `kubectl` access to all target clusters.

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
