#!/bin/bash
echo "Installing essentials"
sudo apt-get update && sudo apt-get -y dist-upgrade
sudo apt-get -y install ubuntu-restricted-addons ubuntu-restricted-extras git openssh-server zsh build-essential

echo "Enabling ssh"
sudo systemctl enable ssh
sudo systemctl start ssh

echo "Running After Effects bootstrap script (unavailable for latest ubuntu yet)"
#sudo ./bootstrap-ubuntu.sh

echo "Setting up docker permissions"
sudo groupadd docker
sudo gpasswd -a $USER docker
newgrp docker

echo "Installing zgen (zsh plugin manager)"
rm -rf "${HOME}/.zgen"
git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"

#echo "Installing oh-my-zsh"
wget --no-check-certificate https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | sh

echo "Setting default shell to zsh"
chsh -s /bin/zsh

echo "Reminder: log completely out of your desktop and back in to have your default shell change to zsh."
echo "When you have logged in again zgen will run and update your configuration per the ~/.envrc* files"

if [ ! -f ~/.zshrc ]; then
    echo ".zshrc not found, creating..."
    cp ../bootstrap/dotfiles/.zshrc* "$HOME"
fi

echo ""
echo "Update/activate zsh configuration: source ~/.zshrc"
