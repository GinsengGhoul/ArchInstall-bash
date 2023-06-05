#!/bin/bash

setup_snapper() {
  arch-chroot /mnt umount "/.snapshots"
  arch-chroot /mnt rm -r "/.snapshots"
  arch-chroot /mnt snapper --no-dbus -c root create-config /
  arch-chroot /mnt btrfs subvolume delete "/.snapshots"
  arch-chroot /mnt mkdir "/.snapshots"
  arch-chroot /mnt mount -a
  arch-chroot /mnt chmod 750 "/.snapshots"
}`

setup_ssh() {

}

enable_services() {
  
}

run() {
  case "$ArchInstallType" in
  laptop|desktop)
    setup_snapper
    ;;
  server)
    setup_ssh
    ;;
  *)
    ;;
  esac

  enable_services
}
