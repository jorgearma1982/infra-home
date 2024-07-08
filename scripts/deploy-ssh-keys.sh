#!/bin/bash

#
# script: deploy-ssh-keys.sh
# author: jorge.medina@kronops.com.mx
# desc: Copy ansible ssh keys to server
#

# main
cd ansible
ansible-playbook deploy-ssh-keys.yml -k -K
