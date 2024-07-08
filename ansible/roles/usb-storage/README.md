usb-storage
===========

Tasks for setting up local usb storage.

Requirements
------------

Debian based system.

Role Variables
--------------

partitions:
  - label: "DATA"
    filesystem: "ext4"
    mount_point: "/mnt/data"
    opts: "defaults"
    owner: "root"
    group: "root"
    mode: "0755"
  - label: "BACKUP"
    filesystem: "ext4"
    mount_point: "/mnt/backup"
    opts: "defaults"
    owner: "root"
    group: "root"
    mode: "0755"

Dependencies
------------

Not at the moment.

Example Playbook
----------------

To use this role, just include it in your playbook, for example:

    - hosts: servers
      roles:
         - usb-storage

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
