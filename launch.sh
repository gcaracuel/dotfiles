#!/usr/bin/env bash

echo "
# Requirements:\n
#   (Fedora): sudo dnf install ansible git python2-dnf\n
#   (OSX): sudo pacman -S ansible\n"

git pull
ansible-playbook -i ansible/inventory ansible/bootstrap.yml $1
