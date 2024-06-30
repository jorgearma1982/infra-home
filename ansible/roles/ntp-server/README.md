ntp-server
===========

Tasks for setting up local NTP service.

Requirements
------------

Ubuntu based system.

Role Variables
--------------

Default ntp servers:

ntp_server_0: 0.mx.pool.ntp.org
ntp_server_1: 1.mx.pool.ntp.org
ntp_server_2: 2.mx.pool.ntp.org
ntp_server_3: 3.mx.pool.ntp.org

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
