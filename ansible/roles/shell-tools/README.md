shell-tools
===========

Tareas para configurar herramientas del shell.

Requirements
------------

Ubuntu based system.

Role Variables
--------------

file_packages:
  - vim
  - git
net_packages:
  - curl
  - dnsutils
  - nmap
admin_packages:
  - screen
  - htop
admin_users:
  - name: root
    group: root
    home: /root
  - name: pi
    group: pi
    home: /home/pi

Dependencies
------------

Not at the moment.

Example Playbook
----------------

To use this role, just include it in your playbook, for example:

    - hosts: servers
      roles:
        - shell-tools

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
