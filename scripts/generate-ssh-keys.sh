#!/bin/bash

#
# script: generate-ssh-keys.sh
# author: Jorge Armando Medina
# desc: Generate SSH ed25519 keys for ansible.

# Bash debug mode
set -x

# Stop on errors
set -e

# vars
KEY_TYPE="ed25519"
KEY_ROUNDS="100"
KEY_DESC="ansible@home"
KEY_DIR="inventory/.ssh"
KEY_FILE="id_ansible_ed25519"

# main
cd ansible

# Create ssh directory
mkdir -p ${KEY_DIR}
chmod 700 ${KEY_DIR}

echo "Generating ${KEY_TYPE}/${KEY_SIZE} SSH keys for ansible user."
ssh-keygen \
  -t ${KEY_TYPE} \
  -a ${KEY_ROUNDS} \
  -C "${KEY_DESC}" \
  -f ${KEY_DIR}/${KEY_FILE} \
  -q -N ""

echo "Changing key permissions to 600."
chmod 600 ${KEY_DIR}/${KEY_FILE}*
cd ..
