#!/bin/bash

#
# script: deploy-ssh-keys.sh
# author: jorge.medina@kronops.com.mx
# desc: Test ansible ssh keys with servers
#

# main
cd ansible
ansible all -m ping
