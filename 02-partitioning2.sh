#!/bin/bash
Gib="1024"
BB="1"
recovery="1024"
logfile="Partition.log"

make_table_only="false"

xfs_format="mkfs.xfs -f "
btrfs_format="mkfs.btrfs -f "
f2fs_format="mkfs.f2fs -O extra_attr,inode_checksum,sb_checksum,compression -f "
ext4_format="mkfs.ext4 -F "
jfs_format="mkfs.jfs "

# no need to add discard=async for ssds for btrfs as it is default
# compression is 1-15, 1 is the fastest, 15 is the highest compression
# 1 saves 40%
# 3 saves 41%
# 9 saves 43%
# https://hackmd.io/kIMJv7yHSiKoAq1MPcCMdw
# in most cases just use 1
# lazytime keeps changes in ram.  if ram is in shortage, don't use it.
# could also use noatime
xfs_mount="defaults,lazytime"
btrfs_mount="defaults,lazytime,discard=async,compress=zstd:1"
f2fs_mount="compress_algorithm=zstd:1,compress_chksum,atgc,gc_merge,lazytime"
ext4_mount="defaults,lazytime"
jfs_mount="defaults,lazytime"

# ef02 - bios boot
# ef00 - efi partition
# 8300 - linux filesystem
# 0700 - Microsoft basic data
# 8200 - Linux swap
# a sting building based on what options are selected
# these are instructions sent to gdisk
#
# "o\ny\n                                Make a new gpt table
# n\n\n\n+"$BB"M\nef02\n                make bios boot
# n\n\n\n+"$EFI"M\nef00\n               make efi partition
# n\n\n\n+"$root"M\n8300\n              make root partition
# n\n\n\n+"$aux"M\n8300\n               make aux partition
# n\n\n\n+"$recovery"M\n0700\n          make recovery partition
# n\n\n\n+"$swap"M\n\n8200\n            make swap partition
# w\ny\n"                               write table
#
partition_drive() {
  gptstr='o\ny\n'
  bbstr='n\n\n\n+'$BB'M\nef02\n'
  efistr='n\n\n\n+'$EFI'M\nef00\n'
  rootstr='n\n\n\n+'$root'M\n8300\n'
  auxstr='n\n\n\n+'$aux'M\n8300\n'
  recoverystr='n\n\n\n+'$recovery'M\n0700\n'
  swapstr='n\n\n\n\n+'$swap'M\n8200\n'
  writestr='w\ny\n'

  # for some reason, the last line needs one more enter...

  # start string_builder
  commands=$gptstr$bbstr$efistr$rootstr
  if [[ "$Aux" = "true" ]]; then
    commands=$commands$auxstr
  fi
  if [[ "$Recovery" = "true" ]]; then
    commands=$commands$recoverystr
  fi
  if [[ "$Swap" = "true" ]]; then
    commands=$commands$swapstr
  fi
  commands=$commands$writestr
  echo $commands
  # override
  #commands=$gptstr$bbstr$efistr$rootstr$auxstr$recoverystr$swapstr$writestr
  #commands=$gptstr$swapstr$writestr
  #echo $commands
  echo -e $commands | gdisk $disk
  #echo -e $commands
  return
}

create_partitiontable() {
  Boot=$((Gib * 1))

  SoftSet BiosBoot true
  SoftSet esp true
  SoftSet Aux true
  SoftSet Recovery true
  SoftSet Swap true

  if [[ "$BiosBoot" = "true" ]]; then
    BB=1
  else
    BB=0
  fi

  if [[ "$Recovery" = "true" ]]; then
    recovery=$((2 * $Gib))
  else
    recovery=0
  fi

  if [[ "$esp" = "true" ]]; then
    # for a single kernel, it's around 128
    SoftSet EFI 2
    # EFI=256
  else
    SoftSet EFI 0
  fi

  if [[ "$Swap" = "true" ]]; then
    # determine swap size
    maxSwapsize=$(($disksize / 5))
    if [ $(($ram * 2)) -le $maxSwapsize ]; then
      swap=$(($ram * 2))
    elif [ $(($ram + $ram / 2)) -le $maxSwapsize ]; then
      swap=$(($ram + $ram / 2))
    elif [ $(($ram)) -le $maxSwapsize ]; then
      swap=$(($ram))
    elif [ $(($ram / 2)) -le $maxSwapsize ]; then
      swap=$(($ram / 2))
    else
      swap=0
    fi
  else
    swap=0
  fi

  if [[ "$Aux" = "true" ]]; then
    local DiskSize=$(($disksize - $BB - $EFI - $recovery - $swap))
    # max root size is 256
    root=$((256 * $Gib))
    local decrease=$((16 * $Gib))
    local maxRoot=$(($DiskSize / 4))

    for ((i = 0; i < 15; i++)); do
      if [ $root -gt $maxRoot ]; then
        root=$(($root - $decrease))
      fi
    done

    aux=$(($DiskSize - $root))

  else
    root=$(($disksize - $BB - $EFI - $recovery - $swap))
    aux=0
  fi

  DiskSize=$(($disksize - $recovery))
  echlog "------------------------------------"

}

print_partitiontable() {
  # print partition table
  echlog "Bios Boot:      $BB"
  echlog "EFI:            $EFI"
  echlog "Root:           $root"
  echlog "Aux:            $aux"
  echlog "Recovery:       $recovery"
  echlog "Swap:           $swap"
  echlog "------------------------------------"
  echlog "Total           $(($BB + $EFI + $root + $aux + $swap + $recovery))"
  echo "lets do it!"
  if [ $(($BB + $EFI + $root + $aux + $swap + $recovery)) -eq $disksize ]; then
    echo "these values seem correct"
  else
    echlog "the numbers aren't numbering"
    echlog "$disksize != $(($BB + $EFI + $root + $aux + $swap + $recovery))"

    return 0
  fi
}

# dynamic numbers to build partition table
format_drive() {
  if [[ "$BiosBoot" == "true" ]]; then
    cp=2
  else
    cp=1
  fi
  echlog "BiosBoot = $BiosBoot, setting cp to $cp"

  if [[ "$esp" = "true" ]]; then
    echlog "formating $disk$cp as a Fat$espformat esp partition"
    mkfs.fat -F$espformat $disk$cp # efi partition
    esppath=$disk$cp
    echlog "esppath = $esppath | $disk$cp"
    ((cp++))
  fi
  echlog "esp = $esp"

  SoftSet rootfs btrfs
  if [[ "$rootfs" = "xfs" ]]; then
    echlog "formating $disk$cp as a XFS root partition"
    command="$xfs_format""-L Arch_root $disk$cp"
    echlog "command = $command"
  elif [[ "$rootfs" = "btrfs" ]]; then
    echlog "formating $disk$cp as a BTRFS root partition"
    command="$btrfs_format""-L Arch_root $disk$cp"
    echlog "command = $command"
  elif [[ "$rootfs" = "f2fs" ]]; then
    echlog "formating $disk$cp as a F2FS root partition"
    command="$f2fs_format""-l Arch_root $disk$cp"
    echlog "command = $command"
  elif [[ "$rootfs" = "ext4" ]]; then
    echlog "formating $disk$cp as a EXT4 root partition"
    command="$ext4_format""-L Arch_root $disk$cp"
    echlog "command = $command"
  elif [[ "$rootfs" = "jfs" ]]; then
    echlog "formating $disk$cp as a JFS root partition"
    command="$jfs_format"" -L Arch_Root $disk$cp"
    echlog "command = $command"
  fi
  $command
  command=""

  rootpath=$disk$cp
  echlog "rootpath = $rootpath | $disk$cp"
  ((cp++))

  SoftSet auxfs btrfs
  if [[ $Aux = "true" ]]; then
    if [[ "$auxfs" = "xfs" ]]; then
      echlog "formating $disk$cp as a XFS Aux partition"
      command="$xfs_format""$disk$cp"
      echlog "command = $command"
    elif [[ "$auxfs" = "btrfs" ]]; then
      echlog "formating $disk$cp as a BTRFS Aux partition"
      command="$btrfs_format""$disk$cp"
      echlog "command = $command"
    elif [[ "$auxfs" = "f2fs" ]]; then
      echlog "formating $disk$cp as a F2FS Aux partition"
      command="$f2fs_format""$disk$cp"
      echlog "command = $command"
    elif [[ "$auxfs" = "ext4" ]]; then
      echlog "formating $disk$cp as a EXT4 Aux partition"
      command="$ext4_format""$disk$cp"
      echlog "command = $command"
    elif [[ "$auxfs" = "jfs" ]]; then
      echlog "formating $disk$cp as a JFS Aux partition"
      command="$jfs_format""$disk$cp"
      echlog "command = $command"
    fi
    $command
    command=""

    auxpath=$disk$cp
    echlog "auxpath = $auxpath | $disk$cp"
    ((cp++))
  fi
  if [[ $Recovery = "true" ]]; then
    mkfs.fat -F32 $disk$cp
    recoverypath=$disk$cp
    echlog "recoverypath = $recoverypath | $disk$cp"
    ((cp++))
  fi
  if [[ $Swap = "true" ]]; then
    echlog "swappath = $disk$cp"
    mkswap $disk$cp
    swapon $disk$cp
    echo "Swap_UUID=$(blkid -s UUID -o value $disk$cp)" >swap
  else
    echo "Swap_UUID=""" >swap
  fi
}

mount_partitions() {
  if [[ "$rootfs" = "xfs" ]]; then
    echlog "Mounting XFS root to /mnt"
    mount -o $xfs_mount $rootpath /mnt
  elif [[ "$rootfs" = "btrfs" ]]; then
    echlog "Mounting BTRFS root to /mnt"
    mount -o $btrfs_mount $rootpath /mnt
  elif [[ "$rootfs" = "f2fs" ]]; then
    echlog "Mounting F2FS root to /mnt"
    mount -o $f2fs_mount $rootpath /mnt
  elif [[ "$rootfs" = "ext4" ]]; then
    echlog "Mounting EXT4 root to /mnt"
    mount -o $ext4_mount $rootpath /mnt
  elif [[ "$rootfs" = "jfs" ]]; then
    echlog "Mounting JFS root to /mnt"
    mount -o $jfs_mount $rootpath /mnt
  fi

  mkdir -p /mnt$espMount
  mount $esppath /mnt$espMount

  SoftSet AuxUse "/home"
  if [[ "$Aux" = "true" ]]; then
    mkdir -p /mnt$AuxUse
    if [[ "$auxfs" = "xfs" ]]; then
      echlog "Mounting XFS aux to /mnt$AuxUse"
      mount -o $xfs_mount $auxpath /mnt$AuxUse
    elif [[ "$auxfs" = "btrfs" ]]; then
      echlog "Mounting BTRFS aux to /mnt$AuxUse"
      mount -o $btrfs_mount $auxpath /mnt$AuxUse
    elif [[ "$auxfs" = "f2fs" ]]; then
      echlog "Mounting F2FS aux to /mnt$AuxUse"
      mount -o $f2fs_mount $auxpath /mnt$AuxUse
    elif [[ "$auxfs" = "ext4" ]]; then
      echlog "Mounting EXT4 aux to /mnt$AuxUse"
      mount -o $ext4_mount_mount $auxpath /mnt$AuxUse
    elif [[ "$auxfs" = "jfs" ]]; then
      echlog "Mounting JFS aux to /mnt$AuxUse"
      mount -o $jfs_mount $auxpath /mnt$AuxUse
    fi
  fi

  if [[ $Recovery = "true" ]]; then
    echlog "Mounting recovery to /mnt/RECOVERY"
    mkdir /mnt/RECOVERY
    mount $recoverypath /mnt/RECOVERY
  fi

}

run() {
  # overrides
  # sizes are in Mib
  #ram=$((1*$Gib))
  #disksize=$((8*$Gib))

  echlog "ram(Mib): $ram"
  echlog "disksize(Mib): $disksize"
  ramGib=$(($ram / $Gib))
  echlog "ramGib: $ramGib"
  echlog "------------------------------------"

  create_partitiontable
  print_partitiontable

  SoftSet make_table_only false
  if [ "$make_table_only" = false ]; then
    mount -l /mnt
    partition_drive
    format_drive
    mount_partitions
  fi
}

source Configuration.cfg
# returns kibibytes
# convert to Mb
ram=$(awk '/MemTotal/{print $2}' /proc/meminfo)
ram=$(($ram / 1024))
#returns bytes so convert to Mib
disksize=$(lsblk -b --output SIZE -n -d $disk)
disksize=$(($disksize / 1048576))
run
