#!/bin/bash
##
apt update
apt install curl -y
wget https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz
gunzip nvim-linux-x86_64.tar.gz
tar xvf nvim-linux-x86_64.tar
rm /bin/nvim
ln -s $(pwd)/nvim-linux-x86_64/bin/nvim /bin/nvim
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install nodejs -y
apt install npm -y
mkdir ~/Templates
mkdir ~/Templstes/nvimplugs
##
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
##
mkdir ~/.config
mkdir ~/.config/nvim
mv ./init.vim ~/.config/nvim
##
