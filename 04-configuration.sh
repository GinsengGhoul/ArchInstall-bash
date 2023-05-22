#!/bin/bash

hostname=Workstation11 #set hostname before run
# common nomenclature is all lowercase however archlinux doesn't
# # stop you from setting one in caps, make sure it doesn't contain
# # special characters

locale=en_US.UTF-8
keymap=us
# # all US keymaps provided by ArchLinux
# # amiga-us
# # atari-us
# # br-latin1-us
# # is-latin1-us
# # us
# # mac-us
# # sunt5-cz-us
timezone="America/Los-Angeles"

setup_nvim(){
  pacman -Sy --root /mnt neovim --needed
  # link nvim as vi and vim
  ln -s /usr/bin/nvim /mnt/usr/bin/vim
  ln -s /usr/bin/nvim /mnt/usr/bin/vi
  # create vimrc
  echo 'set number
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
 map <F4> :nohl<CR>' > /mnt/etc/vimrc
  # create a copy into nvim's config
  cat /etc/vimrc >> /mnt/etc/xdg/nvim/sysinit.vim
}

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
  sudo sed -i '/^vm.swappiness=/s/=.*/=100/' $1
  sudo sed -i '/^vm.swappiness=/a vm.dirty_background_bytes = 16777216' $1
  sudo sed -i '/^vm.swappiness=/a vm.dirty_bytes = 67108864' $1
  sudo sed -i '/^vm.swappiness=/a vm.vfs_cache_pressure=500' $1
}

reenable_features() {
  file="/mnt/etc/modprobe.d/30_security-misc.conf"
  # Use sed to comment out the lines to the specific modules
  # comment out the specific modules that don't neeed to be disabled
  # UDF if you want to
  sed -i 's/^install udf \/bin\/disabled-filesys-by-security-misc/#&/' "$file"
  # intel-me leave disabled(comment these lines) if on AMD
  # or not using intel wireless
  sed -i 's/^install mei-me \/bin\/disabled-intelme-by-security-misc/#&/' "$file"
  sed -i 's/^install mei \/bin\/disabled-intelme-by-security-misc/#&/' "$file"
  # enable bluetooth
  sed -i 's/^install bluetooth \/bin\/disabled-bluetooth-by-security-misc/#&/' "$file"
  sed -i 's/^install btusb \/bin\/disabled-bluetooth-by-security-misc/#&/' "$file"
  # cdrom support
  sed -i 's/^blacklist cdrom/#&/' "$file"
  # scsi cdrom
  sed -i 's/^blacklist sr_mod/#&/' "$file"
}

run() {
  # generate /etc/fstab
  genfstab -U /mnt >> /mnt/etc/fstab
  # add pri=0 to physical swap partition if swap exist
  sed -i '/^\S.*swap/s/\(^\S*\s\+\S\+\s\+\S\+\s\+\)\(\S\+\)\(\s\+.*\)/\1\2,pri=0\3/' /mnt/etc/fstab
  #add tmpfs and zram
  # set limits accordingly
  echo "tmpfs	        /tmp		tmpfs   defaults,noatime,size=2048M,mode=1777	0 0" >> /mnt/etc/fstab
  echo "tmpfs	        /var/cache	tmpfs   defaults,noatime,size=10M,mode=1755	0 0" >> /mnt/etc/fstab
  echo  "/dev/zram0	none    	swap	defaults,pri=32767,discard		0 0" >> /mnt/etc/fstab
  # Create Directories
  dirs=(
    /mnt/etc/modules-load.d
    /mnt/etc/snapper/configs
    /mnt/etc/default
    /mnt/etc/conf.d
    /mnt/etc/sysctl.d/
    /etc/udev/rules.d
    /mnt/etc/NetworkManager/conf.d
    /etc/xdg/nvim/
  )
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
  done

  echo $locale >> /mnt/etc/locale.gen
  echo "LANG="$locale"" > /mnt/etc/locale.conf
  echo "LANG="$locale"" > /mnt/etc/default/locale
  # Setting hostname.
  echo "$hostname" >> /mnt/etc/hostname
  echo "hostname=$hostname" >> /mnt/etc/conf.d/hostname
 

  # Setting hosts file.
  echo "Setting hosts file."
  cat >> /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
::1         $hostname.localdomain   $hostname
EOF

  setup_nvim

  # configure snapper cleanup
  cat >> /mnt/etc/snapper/configs/config <<EOF
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EOF

  # enable zram
  echo 'zram' > /mnt/etc/modules-load.d/zram.conf
  echo 'options zram num_devices=1' > /mnt/etc/modprobe.d/zram.conf
  echo 'KERNEL=="zram0", ATTR{disksize}="'$(half_memory)'" RUN="/usr/bin/mkswap /dev/zram0", TAG+="systemd"' > /mnt/etc/udev/rules.d/99-zram.rules

  # Blacklisting kernel modules
  curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/modprobe.d/30_security-misc.conf >> /mnt/etc/modprobe.d/30_security-misc.conf
  chmod 600 /mnt/etc/modprobe.d/*
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-bluetooth-by-security-misc >> /mnt/bin/disabled-bluetooth-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-cdrom-by-security-misc >> /mnt/bin/disabled-cdrom-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-filesys-by-security-misc >> /mnt/bin/disabled-filesys-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-firewire-by-security-misc >> /mnt/bin/disabled-firewire-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-intelme-by-security-misc >> /mnt/bin/disabled-intelme-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-msr-by-security-misc >> /mnt/bin/disabled-msr-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-netfilesys-by-security-misc >> /mnt/bin/disabled-netfilesys-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-network-by-security-misc >> /mnt/bin/disabled-network-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-thunderbolt-by-security-misc >> /mnt/bin/disabled-thunderbolt-by-security-misc
  curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/bin/disabled-vivid-by-security-misc >> /mnt/bin/disabled-vivid-by-security-misc
  chmod 755 /mnt/bin/disabled*
  chmod +x /mnt/bin/disabled*

  # Security kernel settings.
  curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/sysctl.d/30_security-misc.conf >> /mnt/etc/sysctl.d/30_security-misc.conf
  # This will completely disallow debugging change to lower or disable this if debugging is necessary
  # removing debugging is good or security
  sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /mnt/etc/sysctl.d/30_security-misc.conf
  update_swappiness "/mnt/etc/sysctl.d/30_security-misc.conf"
  curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf >> /mnt/etc/sysctl.d/30_silent-kernel-printk.conf
  chmod 600 /mnt/etc/sysctl.d/*

# IO udev rules, enables bpq scheduler for all disks
  curl https://gitlab.com/garuda-linux/themes-and-settings/settings/performance-tweaks/-/raw/master/usr/lib/udev/rules.d/60-ioschedulers.rules > /mnt/etc/udev/rules.d/60-ioschedulers.rules
  chmod 600 /mnt/etc/udev/rules.d/*

  # Randomize Mac Address.
  # disable if random address is not wanted
  cat > /mnt/etc/NetworkManager/conf.d/00-macrandomize.conf <<EOF
[device]
wifi.scan-rand-mac-address=yes
[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

  chmod 600 /mnt/etc/NetworkManager/conf.d/00-macrandomize.conf
}

run