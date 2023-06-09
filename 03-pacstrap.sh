#!/bin/bash

# added thermald as it only works on intel as of 2023
# https://github.com/intel/thermal_daemon/issues/383
detect_microcode() {
  if [ -z "$microcode" ]; then
    local vendor=$(cat /proc/cpuinfo | grep vendor_id | awk '{print $3}' | head -n1)
    if [[ "$vendor" == "GenuineIntel" ]]; then
      microcode="intel-ucode thermald"
    elif [[ "$vendor" == "AuthenticAMD" ]]; then
      microcode="amd-ucode"
    else
      # what cpu?
      microcode=""
    fi
  fi
}

run() {
  # pacstrap
  detect_microcode
  headers=$kernel-headers
  pacstrap -PK /mnt base base-devel $kernel $headers linux-firmware $microcode reflector $editor cachyos-mirrorlist xyne-mirrorlist cachyos-keyring grub grub-btrfs efibootmgr
}

source Configuration.cfg
run
