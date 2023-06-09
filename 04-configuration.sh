#!/bin/bash

half_memory() {
  total_mem=$(free -m | awk '/^Mem:/{print $2}')
  half_mem=$((total_mem / 2))
  echo "${half_mem}M"
  # override zram size here
}

# cache pressure increases the tendency for the kernel to reclaim cache pages
# swappiness how agressively the system swaps memory pages
# dirty_ratio/byte force synchronous I/O
# dirty_background_ratio/bytes start writing
# normally the linux kernel uses the ratios which are percentages of ram
# however this can lead to issues where the default of 10% to start writing
# and 20% to start synchronous, can be far too big compared to the drive speeds
# for a 16gb system, 10% is 1.6gb which could be over 10 seconds of writeback
# this can be switched back to ratios for NVME drives or larger numbers
# vm.vfs_cache_pressure=500
# vm.swappiness=100
# vm.dirty_background_ratio=1
# vm.dirty_ratio=50
#
# 4194304          4mb
# 16777216        16mb
# 33554432        32mb
# 50331648        48mb
# 67108864        64mb
# 100663296       96mb
# 134217728      128mb
# 268435456      256mb
# 536870912      512mb
# 1073741824    1024mb
update_swappiness() {
  sed -i '/^vm.swappiness=/s/=.*/=100/' $1
  sed -i '/^vm.swappiness=/a vm.dirty_background_bytes = 16777216' $1
  sed -i '/^vm.swappiness=/a vm.dirty_bytes = 67108864' $1
  sed -i '/^vm.swappiness=/a vm.vfs_cache_pressure=500' $1
}

reenable_features() {
  # Use sed to comment out the lines to the specific modules
  # comment out the specific modules that don't neeed to be disabled
  # UDF if you want to
  sed -i 's/^install udf \/bin\/disabled-filesys-by-security-misc/#&/' $1
  # intel-me leave disabled(comment these lines) if on AMD
  # or not using intel wireless
  sed -i 's/^install mei-me \/bin\/disabled-intelme-by-security-misc/#&/' $1
  sed -i 's/^install mei \/bin\/disabled-intelme-by-security-misc/#&/' $1
  # enable bluetooth
  sed -i 's/^install bluetooth \/bin\/disabled-bluetooth-by-security-misc/#&/' $1
  sed -i 's/^install btusb \/bin\/disabled-bluetooth-by-security-misc/#&/' $1
  # cdrom support
  sed -i 's/^blacklist cdrom/#&/' $1
  # scsi cdrom
  sed -i 's/^blacklist sr_mod/#&/' $1
}

install_VTI() {
  arch-chroot /mnt /bin/bash <<EOF
  set -e

  # Create the build directory
  mkdir -p /VTI
  chmod 777 /VTI
  # Create PKGBUILD file
  cat <<EOM >/tmp/VTI/PKGBUILD
pkgname='VTI'
pkgver=1.0
pkgrel=1
pkgdesc="VIM Totally Installed"
arch=('any')
depends=('neovim')
provides=("vim=999.99" "vi=999.99")

package() {
  mkdir -p "\$pkgdir/usr/bin"
  ln -s /usr/bin/nvim "\$pkgdir/usr/bin/vim"
  ln -s /usr/bin/nvim "\$pkgdir/usr/bin/vi"
}

pkgdesc="\$pkgdesc"
EOM
  # Change to the build directory
  cd /VTI
  # Build and install the package
  su - "\$admin" -c "makepkg -si --noconfirm"
EOF
}

create_users() {
  # copy goodies to /usr/share
  cp -r goodies /mnt/usr/share
  # set folders to 644 and filse to 755
  find /mnt/usr/share/goodies -type d -exec chmod 644 {} +
  find /mnt/usr/share/goodies -type f -exec chmod 755 {} +

  for ((i = 0; i < ${#users[@]}; i++)); do
    username=${users[$i]}
    password=${passwords[$i]:-password}         # If no password is set, set password to "password"
    nonadmingroups_arr=("${nonadmingroups[@]}") # Split nonadmingroups string into an array
    admingroups_arr=("${admingroups[@]}")       # Split admingroups string into an array
    shell=${shell[$i]}

    # Create the user
    echo "Creating user: $username"
    arch-chroot /mnt useradd -m -s "$shell" "$username"
    mkdir -p /mnt/home/$username/.config/alacritty
    arch-chroot /mnt cp -r /usr/share/goodies/scripts /home/$username/
    arch-chroot /mnt cp -r /usr/share/goodies/i3 /home/$username/.config
    arch-chroot /mnt cp -r /usr/share/goodies/i3status /home/$username/.config
    arch-chroot /mnt cp -r /usr/share/goodies/sway /home/$username/.config
    arch-chroot /mnt cp /usr/share/goodies/alacritty.yml /home/$username/.config/alacritty
    arch-chroot /mnt chown -R $username /home/$username

    # Set the password
    arch-chroot /mnt chpasswd <<<"$username:$password"

    # Add user to nonadmingroups
    for group in "${nonadmingroups_arr[@]}"; do
      echo "Adding $username to $group"
      arch-chroot /mnt usermod -a -G "$group" "$username"
    done

    # Check if user is also in adminusers list
    if [[ " ${adminusers[@]} " =~ " $username " ]]; then
      for group in "${admingroups_arr[@]}"; do
        # Create the groups if they don't exist
        arch-chroot /mnt groupadd -r "$group"
        echo "Adding $username to $group"
        arch-chroot /mnt usermod -a -G "$group" "$username"
      done
    fi
  done
  jailbreak_admin
}

configure_mounts() {
  # generate /etc/fstab
  echo "Generate fstab."
  genfstab -U /mnt >>/mnt/etc/fstab
  # add pri=0 to physical swap partition if swap exist
  sed -i '/^\S.*swap/s/\(^\S*\s\+\S\+\s\+\S\+\s\+\)\(\S\+\)\(\s\+.*\)/\1\2,pri=0\3/' /mnt/etc/fstab
  #add tmpfs and zram
  # set limits accordingly
  echo "adding tmpfs and zram mounts"
  echo "tmpfs	        /tmp		tmpfs   defaults,noatime,size=2048M,mode=1777	0 0" >>/mnt/etc/fstab
  echo "tmpfs	        /var/cache	tmpfs   defaults,noatime,size=10M,mode=1755	0 0" >>/mnt/etc/fstab
  echo "/dev/zram0	none    	swap	defaults,pri=32767,discard		0 0" >>/mnt/etc/fstab
  # setup tmpfiles.d
  echo "creating /var/cache/pacman tmpfs mountpoint"
  echo "d /var/cache/pacman - - -" >/mnt/etc/tmpfiles.d/pacman-cache.conf
}

setup_ioudev() {
  if [ -n "$bpq" ]; then
    echo "setup disks to use bpq scheduler"
    # IO udev rules, enables bpq scheduler for all disks
    # curl https://gitlab.com/garuda-linux/themes-and-settings/settings/performance-tweaks/-/raw/master/usr/lib/udev/rules.d/60-ioschedulers.rules >/mnt/etc/udev/rules.d/60-ioschedulers.rules
    cat <<EOF >/mnt/etc/udev/rules.d/60-ioschedulers.rules
# Set I/O scheduler for spinning disks (SATA/SCSI)
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

# Set I/O scheduler for NVMe devices
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

# Set I/O scheduler for other devices (non-spinning disks, non-NVMe)
ACTION=="add|change", KERNEL=="sd[a-z]|hd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
EOF
    chmod 600 /mnt/etc/udev/rules.d/*
  fi
}

setup_grub() {
  echo "setup faster grub timeout"
  sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=\"$grub_timeout\"/" /mnt/etc/default/grub
  echo "setting up apparmor boot arguments, disabling zswap and enabling resume"
  sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet\)/\1 lsm=landlock,lockdown,yama,apparmor,bpf zswap.enabled=0/' /mnt/etc/default/grub
  sed -i 's/\(GRUB_CMDLINE_LINUX="[^"]*\)/\1 resume=UUID="'"$Swap_UUID"'"/' /mnt/etc/default/grub
}

setup_mkinitcpio() {
  local HooksOG="HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)"
  local HooksNW="HOOKS=(systemd autodetect modconf kms keyboard keymap consolefont block filesystems fsck resume)"

  # Check if the line already exists in the file
  if grep -Fxq "$HooksOG" "/mnt/etc/mkinitcpio.conf"; then
    # Replace the line with the new line and preserve comments
    sed -i "s@^$HooksOG\$@$HooksNW@" "/mnt/etc/mkinitcpio.conf"
    echo "mkinitcpio.conf has the systemd and resume hook"
  else
    echo "The line was not found in mkinitcpio.conf."
  fi

  echo "set compression to zstd:15"
  sed -i 's/^#\(COMPRESSION="zstd"\)/\1/' /mnt/etc/mkinitcpio.conf
  sed -i 's/^#COMPRESSION_OPTIONS=()/COMPRESSION_OPTIONS=(-v -15)/' /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt mkinitcpio -P
}

create_dirs() {
  # Create Directories
  dirs=(
    /mnt/etc/modules-load.d
    /mnt/etc/snapper/configs
    /mnt/etc/default
    /mnt/etc/conf.d
    /mnt/etc/sysctl.d/
    /mnt/etc/profile.d/
    /mnt/etc/udev/rules.d
    /mnt/etc/NetworkManager/conf.d
    /mnt/etc/NetworkManager/dnsmasq.d/
    /mnt/etc/xdg/nvim/
    /etc/xdg/reflector/
    /mnt/etc/tmpfiles.d/
  )
  for dir in "${dirs[@]}"; do
    echo "creating $dir"
    mkdir -p "$dir"
  done
}

setup_locale() {
  echo "setup locale"
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
  echo "$locale UTF-8" >>/mnt/etc/locale.gen
  echo "LANG=$locale" >/mnt/etc/locale.conf
  echo "LANG=$locale" >/mnt/etc/default/locale
  arch-chroot /mnt locale-gen
}

setup_hosts() {
  # Setting hostname.
  echo "Setting Hostname"
  echo "$hostname" >>/mnt/etc/hostname
  echo "hostname=$hostname" >>/mnt/etc/conf.d/hostname
  # Setting hosts file.
  echo "creating hosts file."
  cat <<EOF >>/mnt/etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
::1         $hostname.localdomain   $hostname
EOF
}

snapper_config() {
  # configure snapper cleanup
  cat <<EOF >/mnt/etc/snapper/configs/config
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="5"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_LIMIT="10"
EOF
  chmod 644 /mnt/etc/snapper/configs/config
}

reflector_config() {
  cat <<EOF >/etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--protocol rsync,https
--country US,CA,MX
--fastest 12
--latest 10
--number 12
EOF
  chmod 644 /etc/xdg/reflector/reflector.conf
}

setup_ccache() {
  cat <<EOF >/mnt/etc/profile.d/ccache.sh
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
if ! ccache -p | grep -q "^compression = true$"; then
  ccache -o compression=true
fi
EOF
  chmod 755 /mnt/etc/profile.d/ccache.sh
}

setup_nvim() {
  pacman -Sy --root /mnt neovim --needed
  # link nvim as vi and vim
  #arch-chroot /mnt ln -s /usr/bin/nvim /usr/bin/vim
  #arch-chroot /mnt ln -s /usr/bin/nvim /usr/bin/vi
  # create vimrc
  cat <<EOF >/mnt/etc/vimrc
set number
set wrap
syntax on
set mouse=
set expandtab
set shiftwidth=2
set softtabstop=2
set tabstop=2
set autoindent
set smartindent
set cc=80,90,100
map <F4> :nohl<CR>
EOF
  # create a copy into nvim's config
  cat /mnt/etc/vimrc >>/mnt/etc/xdg/nvim/sysinit.vim
  # set permissions
  chmod 644 /mnt/etc/vimrc
  chmod 644 /mnt/etc/xdg/nvim/sysinit.vim
  install_VTI
}

install_powerpill() {
  echo "Installing $AUR and powerpill"
  chmod +x /usr/share/libalpm/scripts/*
  arch-chroot /mnt pacman -S --noconfirm $AUR powerpill
  AUR_command update-grub shim-signed
}

enable_zram() {
  if [ -n "$zram" ]; then
    # enable zram
    echo 'zram' >/mnt/etc/modules-load.d/zram.conf
    echo 'options zram num_devices=1' >/mnt/etc/modprobe.d/zram.conf
    echo 'KERNEL=="zram0", ATTR{disksize}="'$(half_memory)'" RUN="/usr/bin/mkswap /dev/zram0", TAG+="systemd"' >/mnt/etc/udev/rules.d/99-zram.rules

    chmod 644 /mnt/etc/modules-load.d/zram.conf
    chmod 644 /mnt/etc/modprobe.d/zram.conf
    chmod 644 /mnt/etc/udev/rules.d/99-zram.rules

  fi
}

blacklist_kernelmodules() {
  echo "disable unused kernel modules for better security"
  # Blacklisting kernel modules
  curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/modprobe.d/30_security-misc.conf >>/mnt/etc/modprobe.d/30_security-misc.conf
  reenable_features "/mnt/etc/modprobe.d/30_security-misc.conf"
  chmod 600 /mnt/etc/modprobe.d/*
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-bluetooth-by-security-misc >>/mnt/bin/disabled-bluetooth-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-cdrom-by-security-misc >>/mnt/bin/disabled-cdrom-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-filesys-by-security-misc >>/mnt/bin/disabled-filesys-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-firewire-by-security-misc >>/mnt/bin/disabled-firewire-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-intelme-by-security-misc >>/mnt/bin/disabled-intelme-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-msr-by-security-misc >>/mnt/bin/disabled-msr-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-netfilesys-by-security-misc >>/mnt/bin/disabled-netfilesys-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-network-by-security-misc >>/mnt/bin/disabled-network-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-thunderbolt-by-security-misc >>/mnt/bin/disabled-thunderbolt-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-vivid-by-security-misc >>/mnt/bin/disabled-vivid-by-security-misc
  chmod 755 /mnt/bin/disabled*
  chmod +x /mnt/bin/disabled*

  # Security kernel settings.
  curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/sysctl.d/30_security-misc.conf >>/mnt/etc/sysctl.d/30_security-misc.conf
  # This will completely disallow debugging change to lower or disable this if debugging is necessary
  # removing debugging is good or security
  sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /mnt/etc/sysctl.d/30_security-misc.conf
  update_swappiness "/mnt/etc/sysctl.d/30_security-misc.conf"
  curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf >>/mnt/etc/sysctl.d/30_silent-kernel-printk.conf
  chmod 600 /mnt/etc/sysctl.d/*
}

update_service_timeout() {
  local timeout_seconds=30
  # Update service startup timeout
  sudo sed -i "/^# TimeoutStartSec=/s/^#//" "/etc/systemd/system.conf"
  sudo sed -i "s/^TimeoutStartSec=.*/TimeoutStartSec=$timeout_seconds/" "/etc/systemd/system.conf"
  # Update service shutdown timeout
  sudo sed -i "/^# TimeoutStopSec=/s/^#//" "/etc/systemd/system.conf"
  sudo sed -i "s/^TimeoutStopSec=.*/TimeoutStopSec=$timeout_seconds/" "/etc/systemd/system.conf"
}

randomize_mac() {
  # Randomize Mac Address.
  # disable if random address is not wanted
  if [ -n "$randomize_mac" ]; then
    echo "Setup NetworkManager to randomize mac addresses"
    cat <<EOF >/mnt/etc/NetworkManager/conf.d/00-macrandomize.conf
[device]
wifi.scan-rand-mac-address=yes
[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

    chmod 600 /mnt/etc/NetworkManager/conf.d/00-macrandomize.conf
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

install_grub() {
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory="/boot/efi" --bootloader-id=Arch --removable
  arch-chroot /mnt grub-install --target=i386-pc "$disk"
  arch-chroot /mnt grub-mkconfig -o "/boot/grub/grub.cfg"
}

setup_secureboot() {
  arch-chroot /mnt cp /usr/share/shim-signed/shimx64.efi /boot/efi/EFI/Arch/
  arch-chroot /mnt cp /usr/share/shim-signed/mmx64.efi /boot/efi/EFI/Arch/
  arch-chroot /mnt efibootmgr --verbose --disk "$disk" --part 2 --create --label "Shim" --loader /boot/efi/EFI/BOOT/shimx64.efi
  arch-chroot /mnt efibootmgr --verbose --disk "$disk" --part 2 --create --label "MOKmanager" --loader /boot/efi/EFI/BOOT/mmx64.efi
}

run() {
  create_users
  configure_mounts
  setup_ioudev
  setup_grub
  setup_mkinitcpio
  create_dirs
  setup_locale
  setup_hosts
  snapper_config
  reflector_config
  setup_ccache
  setup_nvim
  install_powerpill
  enable_zram
  blacklist_kernelmodules
  update_service_timeout
  randomize_mac
  setupNetworkManager_DHCP_DNS
  install_grub
  setup_secureboot
}

source Configuration.cfg
run
