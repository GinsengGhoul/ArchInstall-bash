#!/bin/sh
sudo pacman -Syy && sudo powerpill -Su --noconfirm && paru -Syu --noconfirm --skipreview
sudo rm -r /var/cache/pacman/pkg/*.part
sudo rm -r /var/cache/pacman/pkg/*.aria2c
paru -Sc --noconfirm
~/scripts/updateISO.sh
