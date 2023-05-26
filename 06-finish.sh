#!/bin/bash

setup_snapper() {
  arch-chroot /mnt umount "/.snapshots"
  arch-chroot /mnt rm -r "/.snapshots"
  arch-chroot /mnt snapper --no-dbus -c root create-config /
  arch-chroot /mnt btrfs subvolume delete "/.snapshots"
  arch-chroot /mnt mkdir "/.snapshots"
  arch-chroot /mnt mount -a
  arch-chroot /mnt chmod 750 "/.snapshots"
}
setup_snapper