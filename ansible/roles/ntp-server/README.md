ntp-server
===========

Tasks for setting up local NTP service.

Requirements
------------

Ubuntu based system.

Role Variables
--------------

ntp_servers:
  - 0.mx.pool.ntp.org
  - 1.mx.pool.ntp.org
  - 2.mx.pool.ntp.org
  - 3.mx.pool.ntp.org
local_network: 192.168.101.0/24

Dependencies
------------

Not at the moment.

Example Playbook
----------------

To use this role, just include it in your playbook, for example:

    - hosts: servers
      roles:
         - ntp-server

License
-------

MIT

Author Information
------------------

Please any question, please contact the autor at: jorge.medina@kronops.com.mx.
