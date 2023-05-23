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

# user info
# usernames can contain only
# lowercase letters (a-z)
# uppercase letters (A-Z)
# digits (0-9)
# underscores (_)
# hyphens (-).

users=("user1" "user2")
adminusers=("user2")
# user that will be used for installation of powerpill
admin="user2"

passwords=(
  "password"
  "password"
)

# corresponds with user
shell=("/bin/bash")

#  "games"   # some software needs this group
#  "adm"             # full read access to journal files
#  "log"             # access to /var/log
#  "systemd-journal" # read only access to systemd logs
#  "ftp"             # acess to ftp server files
#  "http"            # acess to http server files
#  "rfkill"          # turn on and off wifi
#  "sys"             # configure cups without root
#  #"uucp"            # access to serial ports
#  #"lp"              # access to parallel ports
#  "wheel"           # can run any root command with password
#  "libvirt"         # virtual machine
#  "kvm"             # virtual machine
usergroups=("games")
admingroups=("adm" "log" "systemd-journal" "ftp" "http" "rfkill" "sys" "wheel" "libvirt" "kvm")

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

setup_nvim(){
  pacman -Sy --root /mnt neovim --needed
  # link nvim as vi and vim
  arch-chroot /mnt ln -s /usr/bin/nvim /usr/bin/vim
  arch-chroot /mnt ln -s /usr/bin/nvim /usr/bin/vi
  # create vimrc
  cat <<EOF > /mnt/etc/vimrc
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
  cat /etc/vimrc >> /mnt/etc/xdg/nvim/sysinit.vim
}

create_users() {
  for ((i=0; i<${#users[@]}; i++)); do
    username=${users[$i]}
    password=${passwords[$i]:-password} # If no password is set, set password to "password"
    usergroups_arr=(${usergroups[$i]}) # Split usergroups string into an array
    admingroups_arr=(${admingroups[$i]}) # Split admingroups string into an array
    shell=${shell[$i]}

    # Create the user
    echo "Creating user: $username"
    arch-chroot /mnt useradd -m -s "$shell" "$username"

    # Set the password
    arch-chroot /mnt chpasswd <<< "$username:$password"

    # Add user to usergroups
    for group in "${usergroups_arr[@]}"; do
      echo "Adding $username to $group"
      arch-chroot /mnt usermod -a -G "$group" "$username"
    done

    # Check if user is also in adminusers list
    if [[ " ${adminusers[@]} " =~ " $username " ]]; then
      for group in "${admingroups_arr[@]}"; do
        if ! getent group "$group" >/dev/null; then
          echo "Creating group: $group"
          arch-chroot /mnt groupadd "$group"
    fi
    done
      # Add user to admingroups
      for group in "${admingroups_arr[@]}"; do
        echo "Adding $username to $group"
        arch-chroot /mnt usermod -a -G "$group" "$username"
      done
    fi
  done
}

run() {
  # generate /etc/fstab
  genfstab -U /mnt >> /mnt/etc/fstab
  # add pri=0 to physical swap partition if swap exist
  sed -i '/^\S.*swap/s/\(^\S*\s\+\S\+\s\+\S\+\s\+\)\(\S\+\)\(\s\+.*\)/\1\2,pri=0\3/' /mnt/etc/fstab
  #add tmpfs and zram
  # set limits accordingly
  echo  "tmpfs	        /tmp		tmpfs   defaults,noatime,size=2048M,mode=1777	0 0" >> /mnt/etc/fstab
  echo  "tmpfs	        /var/cache	tmpfs   defaults,noatime,size=10M,mode=1755	0 0" >> /mnt/etc/fstab
  echo  "/dev/zram0	none    	swap	defaults,pri=32767,discard		0 0" >> /mnt/etc/fstab

  # Create Directories
  dirs=(
    /mnt/etc/modules-load.d
    /mnt/etc/snapper/configs
    /mnt/etc/default
    /mnt/etc/conf.d
    /mnt/etc/sysctl.d/
    /mnt/etc/udev/rules.d
    /mnt/etc/NetworkManager/conf.d
    /mnt/etc/xdg/nvim/
    /mnt/etc/tmpfiles.d/
  )
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir"
  done

  # setup tmpfiles.d
  echo "d /var/cache/pacman - - -" > /mnt/etc/tmpfiles.d/pacman-cache.conf
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

  echo "$locale UTF-8">> /mnt/etc/locale.gen
  echo "LANG=$locale" > /mnt/etc/locale.conf
  echo "LANG=$locale" > /mnt/etc/default/locale
  arch-chroot /mnt locale-gen
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
  create_users
  arch-chroot /mnt su - $admin <<EOF
paru -S powerpill --noconfirm
EOF

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
  reenable_features "/mnt/etc/modprobe.d/30_security-misc.conf"
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
