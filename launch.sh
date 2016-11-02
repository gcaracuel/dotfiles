#!/usr/bin/env bash


# Requirements:
# git & ansible


git pull
ansible-playbook -i ansible/inventory ansible/bootstrap.yml

#if [[ `uname -s` == 'Linux' ]]; then
#  if [[ `gawk -F= '/^NAME/{print $2}' /etc/os-release` == 'fedora' ]]; then
#    ansible-playbook -i ansible/inventory ansible/fedora.yml
#  elif [[ `gawk -F= '/^NAME/{print $2}' /etc/os-release` == 'ubuntu' ]]; then
#    ansible-playbook -i ansible/inventory ansible/ubuntu.yml
#  else
#    echo "Not support Linux distribution"
#  fi
#else
#  ansible-playbook -i ansible/inventory ansible/osx.yml
#fi
