#!/bin/bash

setup_snapper() {
  echo "creating snapper config"
  arch-chroot /mnt umount "/.snapshots"
  arch-chroot /mnt rm -r "/.snapshots"
  arch-chroot /mnt snapper --no-dbus -c root create-config /
  arch-chroot /mnt btrfs subvolume delete "/.snapshots"
  arch-chroot /mnt mkdir "/.snapshots"
  arch-chroot /mnt mount -a
  arch-chroot /mnt chmod 750 "/.snapshots"
}

setup_ssh() {
  echo "setting up dropbear ssh"
  arch-chroot /mnt systemctl enable dropbear
  curl -o dropbear.postinst https://raw.githubusercontent.com/mkj/dropbear/master/debian/dropbear.postinst
  arch-chroot /mnt /bin/bash dropbear.postinst configure
}

setup_samba() {
  echo "setting up samba"
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
  echo "setting up Networking"
  case $networking in
  networkmanager)
    echo "setting up NetworkManger"
    arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"
    arch-chroot /mnt /bin/bash -c "systemctl mask NetworkManager-wait-online"
    ;;
  networkmanagercore)
    echo "using NetworkManager CORE"
    rm /mnt/etc/NetworkManager/conf.d/*
    rm /mnt/etc/NetworkManager/dnsmasq.d/*
    arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"
    arch-chroot /mnt /bin/bash -c "systemctl mask NetworkManager-wait-online"
    ;;
  systemd)
    echo "setting up Systemd-Networkd"
    arch-chroot /mnt /bin/bash -c "systemctl enable systemd-networkd"
    arch-chroot /mnt /bin/bash -c "systemctl enable systemd-resolved"
    arch-chroot /mnt /bin/bash -c "systemctl mask systemd-networkd-wait-online.service"
    rm /mnt/etc/resolv.conf
    arch-chroot /mnt /bin/bash -c "ln -rsf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
    mkdir -p /mnt/etc/systemd/network
    cat <<EOF >/mnt/etc/systemd/network/20-wired.network
[Match]
Name=e*

[Network]
DHCP=yes
EOF
    cat <<EOF >/mnt/etc/systemd/network/25-wireless.network
[Match]
Name=w*

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
  local parser_conf="/mnt/etc/apparmor/parser.conf"
  local write_cache_line="write-cache"
  local cache_loc_line="cache-loc=/etc/apparmor.d/cache.d/"
  
  echo "enabling write cache and relocating the cache location on apparmor"
  
  # Uncomment "write-cache" line
  sed -i "s/^#$write_cache_line/$write_cache_line/" "$parser_conf"

  # Add "cache-loc=/etc/apparmor.d/cache.d/" line under "write-cache" line
  if ! grep -q "^$cache_loc_line" "$parser_conf"; then
    sed -i "/^$write_cache_line/a $cache_loc_line" "$parser_conf"
  fi
  chmod 644 /mnt/etc/apparmor/parser.conf
}

enable_services() {
  echo "enabling services"
  arch-chroot /mnt systemctl enable apparmor
  arch-chroot /mnt systemctl enable acpid
  arch-chroot /mnt systemctl enable tlp
  arch-chroot /mnt systemctl enable reflector.timer
  arch-chroot /mnt systemctl enable systemd-oomd
  arch-chroot /mnt systemctl enable firewalld
  arch-chroot /mnt systemctl enable snapper-timeline.timer
  arch-chroot /mnt systemctl enable snapper-cleanup.timer
  # arch-chroot /mnt systemctl enable grub-btrfs.path
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
  jail_admin
}

source Configuration.cfg
run