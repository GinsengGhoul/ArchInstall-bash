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
  SoftSet rootfs btrfs
  detect_microcode
  headers=$kernel-headers
  if [[ "$rootfs" = "btrfs" ]]; then
  pacstrap -PK /mnt base base-devel $kernel $headers linux-firmware $microcode reflector $editor cachyos-mirrorlist cachyos-keyring cachyos-v3-mirrorlist cachyos-v4-mirrorlist xyne-mirrorlist grub efibootmgr acpid $shell
  else
  pacstrap -PK /mnt base base-devel $kernel $headers linux-firmware $microcode reflector $editor cachyos-mirrorlist cachyos-keyring cachyos-v3-mirrorlist cachyos-v4-mirrorlist xyne-mirrorlist grub efibootmgr acpid grub-btrfs $shell
  fi
}

source Configuration.cfg
run
