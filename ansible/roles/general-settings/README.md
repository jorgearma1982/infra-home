general-settings
================

Common tasks for setting up general settings for Linux servers

Requirements
------------

Debian based system.

Role Variables
--------------

These are default variables for this role:

* hostname_fqdn: "{{ inventory_hostname }}"
* hostname_name: "{{ hostname_fqdn.split('.').0 }}"
* default_locale: en_US.UTF-8
* default_timezone: America/Mexico_City

Dependencies
------------

Not at the moment.

Example Playbook
----------------

To use this role, just include it in your playbook, for example:

    - hosts: servers
      roles:
         - general-settings

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
