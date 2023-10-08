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
  #curl -o dropbear.postinst https://raw.githubusercontent.com/mkj/dropbear/master/debian/dropbear.postinst
  #arch-chroot /mnt /bin/bash dropbear.postinst configure
  curl -sSL https://raw.githubusercontent.com/mkj/dropbear/master/debian/dropbear.postinst | arch-chroot /mnt /bin/bash -s configure
}

setup_samba() {
  echo "setting up samba"
  sambauserssplit="${sambausers[*]}"

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
   valid users = $sambauserssplit @$sambagroup
   public = no
   writable = yes
   printable = no
EOF

  arch-chroot /mnt groupadd -r "$sambagroup"

  echo "$sambausers" | while read -r user; do
    arch-chroot /mnt usermod -aG "$sambagroup" "$user"
  done

  arch-chroot /mnt firewall-cmd --permanent --add-service={samba,samba-client,samba-dc} --zone=public

  for ((i = 0; i < ${#sambausers[@]}; i++)); do
    username="${sambausers[i]}"
    password="${passwords[i]}"

    echo "Setting Samba password for $username..."

    # Set Samba password using smbpasswd command
    echo -e "$password\n$password" | smbpasswd -a "$username"

    if [ $? -eq 0 ]; then
      echo "Password set successfully for $username"
    else
      echo "Failed to set password for $username"
    fi
  done
}

randomize_mac() {
  # Randomize Mac Address.
  # disable if random address is not wanted
  if [ -n "$randomize_mac" ]; then
    echo "Setup NetworkManager to randomize mac addresses"
    cat <<EOF >/mnt/etc/NetworkManager/conf.d/30-macrandomize.conf
[device]
wifi.scan-rand-mac-address=yes
[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

    chmod 600 /mnt/etc/NetworkManager/conf.d/30-macrandomize.conf
  fi
}

setupNetworkManager_DHCP_DNS() {
  cat <<EOF >/mnt/etc/NetworkManager/conf.d/dhcp-client.conf
[main]
dhcp=dhcpcd
EOF

  cat <<EOF >/mnt/etc/NetworkManager/conf.d/dns.conf
[main]
dns=dnsmasq
EOF

  echo "cache-size=1000" >>/mnt/etc/NetworkManager/dnsmasq.d/cache.conf

  chmod 644 /mnt/etc/NetworkManager/dnsmasq.d/*
  chmod 644 /mnt/etc/NetworkManager/conf.d/*
}

setup_networking() {
  echo "setting up Networking"
  case $NetworkingBackend in
  networkmanager)
    echo "setting up NetworkManger"
    randomize_mac
    setupNetworkManager_DHCP_DNS
    arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"
    arch-chroot /mnt /bin/bash -c "systemctl mask NetworkManager-wait-online"
    ;;
  networkmanagercore)
    echo "using NetworkManager CORE"
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

  if [ $ssd = true ]; then
    cat <<EOF >/mnt/etc/systemd/system/boot-fstrim.service
[Unit]
Description=Run fstrim on all mounted filesystems
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/sbin/fstrim -a

[Install]
WantedBy=multi-user.target
EOF
    arch-chroot /mnt systemctl enable boot-fstrim.service
  fi
}

run() {
  arch-chroot /mnt update-grub
  setup_apparmor
  setup_networking

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

  enable_services
  jail_admin
}

source Configuration.cfg
run
