#!/bin/sh
sudo pacman -Syy && sudo powerpill -Su --noconfirm && paru -Syu --noconfirm --skipreview && paru -Sc --noconfirm
