#!/usr/bin/env bash


# usage:
#  ./launch.sh -v  OR   cd ansible && ansible-playbook -i inventory bootstrap.yml
#  (Only update dotfiles)  ./launch.sh  "-v --tags dotfieles"  OR  cd ansible && ansible-playbook -i inventory bootstrap.yml --tags dotfiles


echo "
# Requirements:\n
#   (Fedora): sudo dnf install ansible git\n
#   (OSX): sudo easy_install pip && sudo pip install ansible\n"

git pull
cd ansible && ansible-playbook -i inventory bootstrap.yml $1
