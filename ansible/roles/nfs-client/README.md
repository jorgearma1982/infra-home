nfs-client
================

Install nfs client on linux server

Requirements
------------

Debian based system.

Role Variables
--------------

These are default variables for this role:

* nfs_share: "/mnt/backup"
* nfs_server: "192.168.1.252"
* nfs_path: "/data/backup"

Dependencies
------------

Not at the moment.

Example Playbook
----------------

To use this role, just include it in your playbook, for example:

    - hosts: servers
      roles:
         - nfs-client

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
