# Dotfiles + Dependencies

Requirements will be provisiones using Ansible + dotfiles will be linked to this repository directory.

So far Fedora/CentOS  +  MacOS Sierra are supported. If a dotfile depends on platform then that single dotfile needs to be moved to platform role and removed from Common role if applies.

Please note this project depens on https://github.com/gcaracuel/oh-my-zsh that's my fork of oh-my-zsh to support my personal theme modifications, feel free to fork this and change roles/common/tasks/main.yml Oh-My-ZSH task to clone standard GitHub project instead of mine :)

### Usage:

Clone this repository at your home:
```bash
git clone https://github.com/gcaracuel/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./launch.sh -v
```

### Requirements:

##### MacOS Sierra
* Ansible

```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew ansible
```

##### Fedora

* Ansible

```bash
sudo dnf install ansible
```


### Vagrant validate:
Just get up a ['fedora','osx'] vagrant instance. SSH into it and verify.

Verbose Ansible execution may help
