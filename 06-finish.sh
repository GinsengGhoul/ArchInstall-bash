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

setup_ssh() {
  arch-chroot /mnt systemctl enable dropbear
  curl -o dropbear.postinst https://raw.githubusercontent.com/mkj/dropbear/master/debian/dropbear.postinst
  arch-chroot /mnt /bin/bash dropbear.postinst configure
}

setup_samba() {
  arch-chroot /mnt systemctl enable smb
  cat <<EOF >/mnt/etc/samba/smb.conf
[global]
  server string = ArchServer
  server role = standalone server
  log file = /var/log/samba/%m.log
  log level = 3
  max log size = 50
  dns proxy = no
#============================ Share Definitions ==============================
;[homes]
;   comment = Home Directories
;   browsable = no
;   writable = yes

[SambaShare]
   comment = SambaShare
   path = /SambaShare/
   valid users = "$sambausers" @"$sambagroup"
   public = no
   writable = yes
   printable = no
EOF

  arch-chroot /mnt groupadd -r "$group"

  for user in "${sambausers[@]}"; do
    arch-chroot /mnt usermod -aG "$sambagroup" "$user"
  done

  arch-chroot /mnt firewall-cmd --permanent --add-service={samba,samba-client,samba-dc} --zone=public
}

setup_networking() {
  case $networking in
  networkmanager)
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl mask NetworkManager-wait-online
    ;;
  networkmanagercore)
    rm /mnt/etc/NetworkManager/conf.d/*
    rm /mnt/etc/NetworkManager/dnsmasq.d/*
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl mask NetworkManager-wait-online
    ;;
  systemd)
    arch-chroot /mnt systemctl enable systemd-networkd
    arch-chroot /mnt systemctl mask systemd-networkd-wait-online.service
    arch-chroot /mnt ln -rsf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    cat <<EOF >/mnt/etc/systemd/network/20-wired.network
[Match]
Name=en*

[Network]
DHCP=yes
EOF
    cat <<EOF >/mnt/etc/systemd/network/25-wireless.network
[Match]
Name=wl*

[Network]
DHCP=yes
EOF
    chmod 644 /mnt/etc/systemd/network/20-wired.network
    chmod 644 /mnt/etc/systemd/network/25-wireless.network
    ;;
  *) ;;
  esac
}

setup_apparmor() {
  local parser_conf="/etc/apparmor/parser.conf"
  local write_cache_line="write-cache"
  local cache_loc_line="cache-loc=/etc/apparmor.d/cache.d/"

  # Uncomment "write-cache" line
  sed -i "s/^#$write_cache_line/$write_cache_line/" "$parser_conf"

  # Add "cache-loc=/etc/apparmor.d/cache.d/" line under "write-cache" line
  if ! grep -q "^$cache_loc_line" "$parser_conf"; then
    sed -i "/^$write_cache_line/a $cache_loc_line" "$parser_conf"
  fi
  EOF
}

enable_services() {
  arch-chroot /mnt systemctl enable apparmor
  arch-chroot /mnt systemctl enable acpid
  arch-chroot /mnt systemctl enable tlp
  arch-chroot /mnt systemctl enable reflector.timer
  arch-chroot /mnt systemctl enable systemd-oomd
  arch-chroot /mnt systemctl enable firewalld
  arch-chroot /mnt systemctl enable snapper-timeline.timer
  arch-chroot /mnt systemctl enable snapper-cleanup.timer
  arch-chroot /mnt systemctl enable grub-btrfs.path
  arch-chroot /mnt systemctl enable thermald
  arch-chroot /mnt systemctl enable chronyd
  arch-chroot /mnt systemctl enable logrotate.timer
  arch-chroot /mnt systemctl enable irqbalance
  arch-chroot /mnt systemctl enable ananicy-cpp
  # arch-chroot /mnt systemctl enable doh-client
  arch-chroot /mnt systemctl mask ldconfig.service
}

run() {
  case "$ArchInstallType" in
  laptop | desktop)
    setup_snapper
    ;;
  server)
    setup_ssh
    setup_samba
    ;;
  *) ;;
  esac
  setup_apparmor
  setup_networking
  enable_services
}
