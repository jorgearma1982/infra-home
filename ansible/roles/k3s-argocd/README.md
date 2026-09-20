k3s-argocd
===========

Tasks to install argocd services.

Requirements
------------

Debian based system.

Role Variables
--------------

argocd_namespace: "argocd"
argocd_version: "v3.0.11"
argocd_chart_version: "10.9.2"
argocd_domain: "argocd.hq.kronops.io"
# argocd_cli_url se construye dinámicamente en deploy-local-argocd-cli.yml según SO/arquitectura del controlador:
# Linux x86_64: argocd-linux-amd64
# Linux ARM64: argocd-linux-arm64
# macOS ARM64: argocd-darwin-arm64
# macOS x86_64: argocd-darwin-amd64
argocd_admin_password: "CHANGEME" # pragma: allowlist secret
k3s_admin_user: "{{ ansible_user }}"

Dependencies
------------

This role depends on k3s-master and/or k3s-workers.

Example Playbook
----------------

To use this role, just include it in your playbook, for example:

    - hosts: servers
      roles:
         - k3s-argocd

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
