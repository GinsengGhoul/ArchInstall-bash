#!/bin/bash

logfile=Configuration.log

half_memory() {
  total_mem=$(free -m | awk '/^Mem:/{print $2}')
  half_mem=$((total_mem / 2))
  echlog "${half_mem}M"
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
  sed -i '/^vm.swappiness=/s/=.*/=180/' $1
  sed -i '/^vm.swappiness=/a vm.dirty_background_bytes = 16777216' $1
  sed -i '/^vm.swappiness=/a vm.dirty_bytes = 67108864' $1
  sed -i '/^vm.swappiness=/a vm.vfs_cache_pressure=500' $1
  sed -i '/^vm.swappiness=/a vm.watermark_boost_factor = 0' $1
  sed -i '/^vm.swappiness=/a vm.watermark_scale_factor = 125' $1
  sed -i '/^vm.swappiness=/a vm.page-cluster = 0' $1
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
  arch-chroot /mnt /bin/bash <<'EOF'
  set -e

  # Create the build directory
  mkdir -p /tmp/VTI
  chmod 777 /tmp/VTI
  # Create PKGBUILD file
  cat <<'EOM' >/tmp/VTI/PKGBUILD
pkgname='VTI'
pkgver=1.0
pkgrel=1
pkgdesc="VIM Totally Installed"
arch=('any')
depends=('neovim')
provides=("vim=999.99" "vi=999.99")

package() {
  mkdir -p $pkgdir/usr/bin
  ln -s /usr/bin/nvim $pkgdir/usr/bin/vim
  ln -s /usr/bin/nvim $pkgdir/usr/bin/vi
}

EOM

  chown "$admin" /tmp/VTI/PKGBUILD
  # Change to the build directory
  cd /tmp/VTI
  # Build and install the package
  su "$admin" -c "makepkg -si --noconfirm"
  # rm -r /tmp/VTI
EOF
}

create_users() {
  # copy goodies to /usr/share
  cp -r goodies /mnt/usr/share
  # set folders to 644 and filse to 755
  find /mnt/usr/share/goodies -type d -exec chmod 644 {} +
  find /mnt/usr/share/goodies -type f -exec chmod 755 {} +

  arch-chroot /mnt chpasswd <<<"root:$rootpassword"

  for ((i = 0; i < ${#users[@]}; i++)); do
    username=${users[$i]}
    password=${passwords[$i]:-password}         # If no password is set, set password to "password"
    nonadmingroups_arr=("${nonadmingroups[@]}") # Split nonadmingroups string into an array
    admingroups_arr=("${admingroups[@]}")       # Split admingroups string into an array
    Shell="/bin/$shell"

    # Create the user
    echlog "Creating user: $username"
    arch-chroot /mnt useradd -m -s "$Shell" "$username"
    mkdir -p /mnt/home/$username/.config/alacritty
    arch-chroot /mnt cp -r /usr/share/goodies/scripts /home/$username/
    arch-chroot /mnt cp -r /usr/share/goodies/i3 /home/$username/.config
    arch-chroot /mnt cp -r /usr/share/goodies/i3status /home/$username/.config
    arch-chroot /mnt cp -r /usr/share/goodies/sway /home/$username/.config
    arch-chroot /mnt cp /usr/share/goodies/alacritty.yml /home/$username/.config/alacritty
    arch-chroot /mnt chown -R $username /home/$username/scripts
    arch-chroot /mnt chown -R $username /home/$username/.config
    arch-chroot /mnt chmod 755 -R /home/$username/scripts
    arch-chroot /mnt chmod 755 -R /home/$username/.config

    # Set the password
    arch-chroot /mnt chpasswd <<<"$username:$password"

    # Add user to nonadmingroups
    for group in "${nonadmingroups_arr[@]}"; do
      echlog "Adding $username to $group"
      arch-chroot /mnt usermod -a -G "$group" "$username"
    done

    # Check if user is also in adminusers list
    if [[ " ${adminusers[@]} " =~ " $username " ]]; then
      for group in "${admingroups_arr[@]}"; do
        # Create the groups if they don't exist
        arch-chroot /mnt groupadd -r "$group"
        echlog "Adding $username to $group"
        arch-chroot /mnt usermod -a -G "$group" "$username"
      done
    fi
  done
  jailbreak_admin
}

configure_mounts() {
  # generate /etc/fstab
  echlog "Generate fstab."
  genfstab -U /mnt >>/mnt/etc/fstab
  # add pri=0 to physical swap partition if swap exist
  sed -i '/^\S.*swap/s/\(^\S*\s\+\S\+\s\+\S\+\s\+\)\(\S\+\)\(\s\+.*\)/\1\2,pri=0\3/' /mnt/etc/fstab
  #add tmpfs and zram
  # set limits accordingly
  echlog "adding tmpfs and zram mounts"
  echlog "tmpfs	        /tmp		tmpfs   defaults,noatime,size=2048M,mode=1777	0 0" >>/mnt/etc/fstab
  echlog "tmpfs	        /var/cache	tmpfs   defaults,noatime,size=10M,mode=1755	0 0" >>/mnt/etc/fstab
  echlog "/etc/pacman.d/pacman-cache /var/cache/pacman none bind,x-mount.mkdir 0 0" >>/mnt/etc/fstab
  echlog "/dev/zram0	none    	swap	defaults,pri=32767,discard		0 0" >>/mnt/etc/fstab
  # setup tmpfiles.d
  echlog "creating /var/cache/pacman bindfs mountpoint"
  mkdir -p /mnt/etc/pacman.d/pacman-cache/pkg
}

setup_ioudev() {
  if [ -n "$bpq" ]; then
    echlog "setup disks to use bpq scheduler"
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
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/default/grub.d/40_cpu_mitigations.cfg >/mnt/etc/grub.d/40_cpu_mitigations
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/default/grub.d/40_distrust_cpu.cfg >/mnt/etc/grub.d/40_distrust_cpu
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/default/grub.d/40_enable_iommu.cfg >/mnt/etc/grub.d/40_enable_iommu
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/default/grub.d/40_kernel_hardening.cfg >/mnt/etc/grub.d/40_kernel_hardening
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/default/grub.d/40_distrust_bootloader.cfg >/mnt/etc/grub.d/40_distrust_bootloader
  sed -i 's/^kpkg=/#kpkg=/; s/^kver=/#kver=/' /mnt/etc/grub.d/40_kernel_hardening
  chmod 755 /mnt/etc/grub.d/*

  echlog "setup faster grub timeout"
  sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=\"$grub_timeout\"/" /mnt/etc/default/grub
  echlog "setting up apparmor boot arguments, disabling zswap and enabling resume"
  sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet\)/\1 lsm=landlock,lockdown,yama,apparmor,bpf zswap.enabled=0 transparent_hugepage=never/' /mnt/etc/default/grub
  # check if swap_UUID exist
  if [ ! -z "$Swap_UUID" ]; then
    sed -i 's/\(GRUB_CMDLINE_LINUX="[^"]*\)/\1 resume=UUID="'"$Swap_UUID"'"/' /mnt/etc/default/grub
  fi
  SoftSet Recovery true
  if [[ "$Recovery" = "true" ]]; then
    echlog "Downloading newest ArchIso from https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
    curl -o /mnt/RECOVERY/archlinux-x86_64.iso https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
    local RECOVERY=$(blkid | awk -F '[" ]' '/PARTLABEL="Microsoft basic data"/ {for (i=1; i<NF; i++) if ($i == "UUID=") print $(i+1)}')
    cat <<EOF >>/mnt/etc/grub.d/40_custom
menuentry "Arch Linux ISO" {
    search --set=root --file "/archlinux-x86_64.iso"
    loopback loop "/archlinux-x86_64.iso"

    linux (loop)/arch/boot/x86_64/vmlinuz-linux img_dev=UUID=$RECOVERY img_loop="/archlinux-x86_64.iso"
    initrd (loop)/arch/boot/x86_64/initramfs-linux.img
}
EOF
  fi
}

setup_mkinitcpio() {
  local HooksOG="HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)"
  local HooksNW="HOOKS=(systemd autodetect modconf kms keyboard keymap consolefont block filesystems fsck resume)"

  # Check if the line already exists in the file
  if grep -Fxq "$HooksOG" "/mnt/etc/mkinitcpio.conf"; then
    # Replace the line with the new line and preserve comments
    sed -i "s@^$HooksOG\$@$HooksNW@" "/mnt/etc/mkinitcpio.conf"
    echlog "mkinitcpio.conf has the systemd and resume hook"
  else
    echlog "The line was not found in mkinitcpio.conf."
  fi

  echlog "set compression to zstd:15"
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
    echlog "creating $dir"
    mkdir -p "$dir"
  done
}

setup_locale() {
  echlog "setup locale"
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
  echlog "$locale UTF-8" >>/mnt/etc/locale.gen
  echlog "LANG=$locale" >/mnt/etc/locale.conf
  echlog "LANG=$locale" >/mnt/etc/default/locale
  chmod 644 /mnt/etc/locale.conf
  chmod 644 /mnt/etc/default/locale
  arch-chroot /mnt locale-gen
}

setup_hosts() {
  # Setting hostname.
  echlog "Setting Hostname"
  echlog "$hostname" >>/mnt/etc/hostname
  echlog "hostname=$hostname" >>/mnt/etc/conf.d/hostname
  # Setting hosts file.
  echlog "creating hosts file."
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
  cat <<EOF >/mnt/etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--protocol rsync,https
--country US,CA,MX
--fastest 12
--latest 10
--number 12
EOF
  chmod 644 /mnt/etc/xdg/reflector/reflector.conf
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
  echlog "Installing $AUR and powerpill"
  chmod +x /usr/share/libalpm/scripts/*
  arch-chroot /mnt pacman -S --noconfirm $AUR powerpill
  AUR_command update-grub shim-signed
}

enable_zram() {
  if [ -n "$zram" ]; then
    # enable zram
    echlog 'zram' >/mnt/etc/modules-load.d/zram.conf
    echlog 'options zram num_devices=1' >/mnt/etc/modprobe.d/zram.conf
    echlog 'ACTION=="add", KERNEL=="zram0", ATTR{comp_algorithm}="zstd", ATTR{disksize}="'$(half_memory)'", RUN="/usr/bin/mkswap -U clear /dev/%k", TAG+="systemd"' >/mnt/etc/udev/rules.d/99-zram.rules

    chmod 644 /mnt/etc/modules-load.d/zram.conf
    chmod 644 /mnt/etc/modprobe.d/zram.conf
    chmod 644 /mnt/etc/udev/rules.d/99-zram.rules

  fi
}

blacklist_kernelmodules() {
  echlog "disable unused kernel modules for better security"
  # Blacklisting kernel modules
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf >/mnt/etc/modprobe.d/30_security-misc.conf
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
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf >/mnt/etc/sysctl.d/990-security-misc.conf
  # This will completely disallow debugging change to lower or disable this if debugging is necessary
  # removing debugging is good or security
  sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /mnt/etc/sysctl.d/990-security-misc.conf
  update_swappiness "/mnt/etc/sysctl.d/990-security-misc.conf"
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf >/mnt/etc/sysctl.d/30_silent-kernel-printk.conf
  chmod 600 /mnt/etc/sysctl.d/*
}

update_service_timeout() {
  local timeout_seconds=30

  # Update service startup timeout
  sudo sed -i "/\[Manager\]/a TimeoutStartSec=$timeout_seconds" "/etc/systemd/system.conf"

  # Update service shutdown timeout
  sudo sed -i "/\[Manager\]/a TimeoutStopSec=$timeout_seconds" "/etc/systemd/system.conf"
}

update_flags() {
  local file_path=$1

  if [ -f "$file_path" ]; then
    # Update CFLAGS
    sed -i 's/-march=x86-64 -mtune=generic -O2 -pipe/-march=native -O2 -ftree-vectorize -fasynchronous-unwind-tables -pipe/' "$file_path"

    # Update LDFLAGS
    sed -i 's/-Wl,-O1/-Wl,-O2/' "$file_path"
    sed -i 's/-as-needed/-as-needed,z,defs/' "$file_path"

    # Update RUSTFLAGS
    sed -i 's/#RUSTFLAGS="-C opt-level=2"/RUSTFLAGS="-C opt-level=2 -C target-cpu=native"/' "$file_path"

    # use ccache
    sed -i '/^BUILDENV=/ s/!ccache/ccache/' "$file_path"

    # make and ninja flags
    sed -i '/#MAKEFLAGS="-j2"/a MAKEFLAGS="-j$(nproc)"\nNINJAFLAGS="-j$(nproc)"' "$file_path"
  else
    echlog "File not found: $file_path"
  fi
}

install_grub() {
  SoftSet esp true
  SoftSet espMount "/boot/efi"
  arch-chroot /mnt grub-install --target=i386-pc "$disk" | tee -a grub.log
  arch-chroot /mnt grub-mkconfig -o "/boot/grub/grub.cfg" | tee -a grub.log
  if [[ "$esp" = "true" ]]; then
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory="$espMount" --removable | tee grub.log
    setup_secureboot
  fi
}

setup_secureboot() {
  local logfile="grub.log"
  echlog "moving /mnt$espMount/EFI/BOOT/BOOTx64.EFI to /mnt$espMount/EFI/BOOT/grubx64.efi"
  mv /mnt$espMount/EFI/BOOT/BOOTx64.EFI /mnt$espMount/EFI/BOOT/grubx64.efi | tee -a grub.log
  echlog "cp from chroot /usr/share/shim-signed/shimx64.efi to $espMount/EFI/BOOT/BOOTx64.EFI"
  arch-chroot /mnt cp /usr/share/shim-signed/shimx64.efi $espMount/EFI/BOOT/BOOTx64.EFI | tee -a grub.log
  echlog "cp from chroot /usr/share/shim-signed/mmx64.efi to $espMount/EFI/BOOT/"
  arch-chroot /mnt cp /usr/share/shim-signed/mmx64.efi $espMount/EFI/BOOT/ | tee -a grub.log
  local part=$(<"espPart")
  echlog "read esp part from espPart, part: $part"
  arch-chroot /mnt efibootmgr --unicode --disk $disk --part $part --create --label "Shim" --loader /EFI/BOOT/BOOTx64.EFI | tee -a grub.log
  # arch-chroot /mnt efibootmgr --verbose --disk "$disk" --part $part --create --label "MOKmanager" --loader /EFI/BOOT/mmx64.efi | tee -a grub.log
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
  install_grub
  update_flags "/mnt/etc/makepkg.conf"
}

source Configuration.cfg
source swap
run
