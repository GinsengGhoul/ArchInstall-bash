#!/bin/bash
# kernel could be any of the ones in official arch repos or
# cachyOS repos
kernel=linux-cachyos
headers=$kernel-headers
editor=neovim

# microcode override, the script will try to do it automatically
# options are intel-ucode and amd-ucode
microcode=

# added thermald as it only works on intel as of 2023
# https://github.com/intel/thermal_daemon/issues/383
detect_microcode() {
  local vendor=$(cat /proc/cpuinfo | grep vendor_id | awk '{print $3}' | head -n1)
  if [[ "$vendor" == "GenuineIntel" ]]; then
    microcode="intel-ucode thermald"
  elif [[ "$vendor" == "AuthenticAMD" ]]; then
    microcode="amd-ucode"
  else
    # what cpu?
    microcode=""
  fi
}

run() {
  # pacstrap
  detect_microcode
  pacstrap -PK /mnt base base-devel $kernel $headers linux-firmware $microcode reflector $editor cachyos-mirrorlist cachyos-keyring grub grub-btrfs efibootmgr
}

run
