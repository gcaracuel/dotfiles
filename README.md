# Dotfiles + Dependencies

Requirements will be provisioned using Ansible + dotfiles will be linked to this repository directory.

So far Fedora/CentOS  +  MacOS Sierra are supported. If a dotfile depends on platform then that single dotfile needs to be moved to platform role and removed from Common role if applies.

Please note this project comes with my customized configuration... but you can easily change packages + dotfiles (change with_items statements) and paster your dotfiles copies.

### Usage:

Clone this repository at your home:
```bash
git clone https://github.com/gcaracuel/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./launch.sh
```

### Requirements:

##### MacOS
* Ansible

```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew ansible
```

* iterm2

```
1. Open iTerm2.
2. Select iTerm2 > Preferences.
3. Under the General tab, check the box labeled "Load preferences from a custom folder or URL:"
4. Press "Browse" and point it to ~/dotfiles/dotfiles/com.googlecode.iterm2.plist
5. Restart iTerm2.
```


##### Fedora

* Ansible

```bash
sudo dnf install ansible git
```

* Gnome-terminal / iTerm2 themes from: https://github.com/chriskempson/tomorrow-theme

### Vagrant validate:
Just get up a ['fedora','osx'] vagrant instance. SSH into it and verify.

Verbose Ansible execution may help

Note OSX Vagrant box will clone this repository instead of use the local copy, so changes needs to be pushed to be verified :(
