#!/bin/bash

logfile=Pacstrap.log

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
  SoftSet esp true
  detect_microcode
  headers=$kernel-headers
  packages="base base-devel $kernel $headers linux-firmware $microcode reflector $editor cachyos-mirrorlist cachyos-keyring cachyos-v3-mirrorlist cachyos-v4-mirrorlist xyne-mirrorlist grub acpid $shell aria2 mkinitcpio"
  if [[ "$esp" = "true" ]]; then
    packages+=" efibootmgr"
  fi
  echlog "Base: $packages"
  sh -c "pacstrap -PK /mnt $packages"
}

source Configuration.cfg
run
