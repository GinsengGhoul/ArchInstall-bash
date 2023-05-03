#! /bin/bash
# setups creates configs for vim and puts it into neovim
# make sure nvim is installed
pacman -Sy nvim --needed
# link nvim as vi and vim
ln -s /usr/bin/nvim /usr/bin/vim
ln -s /usr/bin/nvim /usr/bin/vi
# create vimrc
echo 'set number
set wrap
syntax on
set mouse=
set expandtab
set shiftwidth=2
set autoindent
set smartindent' > /etc/vimrc
# create a copy into nvim's config
cat /etc/vimrc >> /etc/xdg/nvim/sysinit.vim
