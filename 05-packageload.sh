#!/bin/bash
# basic install
# pacstrap -PK /mnt base base-devel $kernel $headers linux-firmware $microcode neovim cachyos-mirrorlist cachyos-keyring
# other packages

# leave empty for false
ArchServer=
DE=KDE
# this script allows for the following DEs
# Deepin
# KDE
# KDE-wayland
# Cinnamon
# Mate
# XFCE
# LXDE
# LXQT
# icewm
# i3
# sway


#  video - if you’re nvidia you should be installing xf86-video-nouveau
#          if you’re intel and are using gen4 or older hardware(pre core i series) you should use xf86-video-intel
#          if you are anything newer than that, it’s best to not install xf86-video-intel and use kernel modesetting
#          with the appropriate mesa package:
#              if you are gen7(ivybridge) or older use mesa-amber
#              for all others use the normal mesa, this doesn’t effect amd or nvidia unless you are using 
# 		   something VERY VERY ancient
#          if you’re amd you should be installing xf86-video-amdgpu
#  WIFI - if you are using an intel wifi card it may be better to install iw instead of wpa_supplicant
#  video-acceleration - 	
#				INTEL   - older than broadwell(5th gen intel core i) use libva-intel-driver
# 					    - broadwell and up use intel-media-driver
# 				AMD	    - Radeon R300 to HD 2000 install mesa-vdpau
# 					    - Radeon HD 2000 and up install both mesa-vdpau and libva-mesa-driver
#               NVIDIA	- if you’re tesla to kepler v2 AND using nouveau
# 					    - install libva-mesa-driver and mesa-vdpau
# 					    - you’ll also need nouveau-fw
# 					    - if you’re using nvidia’s proprietary stuff install nvidia-utils
#  these are supplimental but not from official repos
#                       - for GMA4500 h264 decoding you’ll want this libva-intel-driver-g45-h264
# 						do note this gpu is literally so weak it probably isn’t worth it
# 	for haswell refresh to skylake vp9 decoding or broadwell to skylake hybrid vp8 decoding
#  	install intel-hybrid-codec-driver
#  reference here: https:# wiki.archlinux.org/title/Hardware_video_acceleration 
#  browser - firefox-developer-edition vivaldi opera
#  pick your poison for vivaldi and opera you’ll need to also install
#  vivaldi-ffmpeg-codecs or opera-ffmpeg-codecs along with the original package
#  don’t install dns-over-https if you want native normal dns resolving, or do and mask the service
#
#  you don’t HAVE to use networkmanger, if you could live with just iwctl, systemd-resolv + systemd-networkd or connman you do you
#  however most DEs support networkmanager best so it’s the one I setup
#  for systemd leave networking blank
#
#  bluetooth - install both bluez and bluez-utils if you want bluetooth, I am content with using bluetoothctl
#  in terminal however if you want a GUI there’s blueman or blueberry.  Blueberry comes from cinnamon so
#  if you want to choose cinnamon as your DE you don’t need to install either of these, KDE and gnome also
#  come with one installed
AUR="paru"
bootloader="grub grub-btrfs efibootmgr"
snapper="snapper snap-pac snap-sync"
optimizations="ccahe irqbalance ananicy-cpp chrony"
computer_signals="acpid tlp"
git="git curl wget rsync"
ssh="dropbear samba"
mesa="mesa-amber lib32-mesa-amber"
video="$mesa"
3d_video="vulkan-intel vulkan-mesa-layers lib32-vulkan-mesa-layers"
video_acceleration="libva-intel-driver"
networking="networkmanager dhcpcd dnsmasq firewalld"
ssh="dropbear samba"
wifi="iw"
browser="firefox-developer-edition"
bluetooth="bluetooth-support"
editor="neovim nano"
fstools="ntfs-3g dosfstools exfatprogs btrfs-progs mtools"
fonts="noto-fonts noto-fonts-cjk ttf-joypixels noto-fonts-extra ttf-ibm-plex"
KVM="qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat ebtables iptables-nft libguestfs edk2-ovmf swtpm"

install_DE(){
  case "$DE" in
    "Deepin")
        arch-chroot /mnt powerpill -S xorg lightdm lightdm-slick-greeter deepin deepin-extra deepin-kwin
        ;;
    "KDE")
        arch-chroot /mnt powerpill -S xorg plasma kde-graphics-meta kde-system-meta kde-utilities-meta breeze-gtk
        ;;
    "KDE-wayland")
        arch-chroot /mnt powerpill -S wayland plasma kde-graphics-meta kde-system-meta kde-utilities-meta breeze-gtk plasma-wayland-session
        ;;
    "Cinnamon")
        arch-chroot /mnt powerpill -S xorg lightdm lightdm-slick-greeter cinnamon gnome-terminal file-roller xed xreader gnome-calculator gnome-font-viewer gnome-screenshot xdg-utils gvfs-mtp gvfs-gphoto2 gvfs-afc
        ;;
    "Mate")
        arch-chroot /mnt powerpill -S
        ;;
    "XFCE")
        arch-chroot /mnt powerpill -S
        ;;
    "LXDE")
        arch-chroot /mnt powerpill -S
        ;;
    "LXQT")
        arch-chroot /mnt powerpill -S
        ;;
    "icewm")
        arch-chroot /mnt powerpill -S
        ;;
    "i3")
        arch-chroot /mnt powerpill -S
        ;;
    "sway")
        arch-chroot /mnt powerpill -S
        ;;
    *)
        # Code to execute when variable doesn't match any previous cases
        ;;
esac
}

# use powerpill for multithreaded downloads
packages="$bootloader $snapper $video $3d_video $video_acceleration $networking $ssh $browser $bluetooth $editor $fstools $fonts $qemu"
aurpkgs="powerpill update-grub"
run() {  
  cat 
}

run
