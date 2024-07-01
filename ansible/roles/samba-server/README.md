samba-server
===========

Tasks for setting up local Samba CIFS service.

Requirements
------------

Debian based system.

Role Variables
--------------

samba_server_string: "NAS 01"
samba_workgroup: "HQ"
samba_netbios_name: "NAS01"
samba_public_shared_name: "Publico"
samba_public_shared_path: "/home/pi/publico"
samba_private_shared_name: "Privado"
samba_private_shared_path: "/home/pi/privado"
samba_public_shared_owner: root
samba_private_shared_owner: "{{ ansible_user }}"
samba_public_create_mask: '0777'
samba_public_directory_mask: '0777'
samba_private_create_mask: '0770'
samba_private_directory_mask: '0770'
samba_group_name: "homelab"
samba_users:
  - { username: "pi", password: "CHANGEME" }

Dependencies
------------

Not at the moment.

Example Playbook
----------------

To use this role, just include it in your playbook, for example:

    - hosts: servers
      roles:
         - samba-server

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
