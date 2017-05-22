#!/usr/bin/env bash


# usage:
#  ./launch.sh -v  OR   cd ansible && ansible-playbook -i inventory bootstrap.yml
#  (Only update dotfiles)  ./launch.sh  "-v --tags dotfiles"  OR  cd ansible && ansible-playbook -i inventory bootstrap.yml --tags dotfiles

echo "
#### #### ####
# Requirements:
#   (Fedora): sudo dnf install ansible git
#   (OSX): sudo easy_install pip && sudo pip install --upgrade pip && sudo pip install --upgrade ansible
#### #### ####
"

git pull
cd ansible && ansible-playbook -i inventory bootstrap.yml -K -v $1
