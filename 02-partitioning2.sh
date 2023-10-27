#!/bin/bash
Gib="1024"
BB="1"
recovery="1024"
logfile="Partition.log"

make_table_only="true"

xfs_format="mkfs.xfs -f "
btrfs_format="mkfs.btrfs -f "
f2fs_format="mkfs.f2fs -f "
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
  if [ $aux -gt 0 ]; then
    commands=$commands$auxstr
  fi
  if [ $make_recovery == true ]; then
    commands=$commands$recoverystr
  fi
  if [ $swap -gt 0 ]; then
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
  SoftSet Recovery true
  SoftSet Aux true
  SoftSet Swap true

  if [ $BiosBoot=true ]; then
    BB=1
  else
    BB=0
  fi

  if [ $Recovery=true ]; then
    recovery=$Gib
  else
    recovery=0
  fi

  if [ $esp=true ]; then
    # for a single kernel, it's around 128
    EFI=256
  else
    EFI=0
  fi

  if [ $Swap=true ]; then
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

  if [ $Aux=true ]; then
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
  echlog "------------------------------------" $logfile

}

print_partitiontable() {
  # print partition table
  echlog "Bios Boot:      $BB" $logfile
  echlog "EFI:            $EFI" $logfile
  echlog "Root:           $root" $logfile
  echlog "Aux:            $aux" $logfile
  echlog "Recovery:       $recovery" $logfile
  echlog "Swap:           $swap" $logfile
  echlog "------------------------------------" $logfile
  echlog "Total           $(($BB + $EFI + $root + $aux + $swap + $recovery))" $logfile
  echo "lets do it!"
  if [ $(($BB + $EFI + $root + $aux + $swap + $recovery)) -eq $disksize ]; then
    echo "these values seem correct"
  else
    echlog "the numbers aren't numbering" $logfile
    echlog "$disksize != $(($BB + $EFI + $root + $aux + $swap + $recovery))" $logfile

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

  if [{ "$esp" = "true" }]; then
    mkfs.fat -F32 $disk$cp # efi partition
    efipath=$disk$cp
    ((cp++))
  fi

  if [[ "$rootfs" = "xfs" ]]; then
    command="$xfs_format""-L Arch_root $dev$cp"
  elif [[ "$rootfs" = "btrfs" ]]; then
    command="$f2fs_format""-L Arch_root $dev$cp"
  elif [[ "$rootfs" = "f2fs" ]]; then
    command="$f2fs_format""-l Arch_root $dev$cp"
  elif [[ "$rootfs" = "ext4" ]]; then
    command="$ext4_format""-L Arch_root $dev$cp"
  elif [[ "$rootfs" = "jfs" ]]; then
    command="$jfs_format"" -L Arch_Root $dev$cp"
  fi
  exec $command
  rootpath=$disk$cp
  command=""
  ((cp++))

  if [[ $Aux = "true" ]]; then
    if [[ "$auxfs" = "xfs" ]]; then
      command="$xfs_format""$dev$cp"
    elif [[ "$auxfs" = "btrfs" ]]; then
      command="$f2fs_format""$dev$cp"
    elif [[ "$auxfs" = "f2fs" ]]; then
      command="$f2fs_format""$dev$cp"
    elif [[ "$auxfs" = "ext4" ]]; then
      command="$ext4_format""$dev$cp"
    elif [[ "$auxfs" = "jfs" ]]; then
      command="$jfs_format""$dev$cp"
    fi

    auxpath=$disk$cp
    ((cp++))
  fi
  if [ $recovery -gt 0 ]; then
    mkfs.fat -F32 $disk$cp
    recoverypath=$disk$cp
    ((cp++))
  fi
  if [ $swap -gt 0 ]; then
    mkswap $disk$cp
    swapon $disk$cp
    echo "Swap_UUID=$(blkid -s UUID -o value $disk$cp)" >swap
  else
    echo "Swap_UUID=""" >swap
  fi
}

mount_partitions() {
  if [[ "$rootfs" = "xfs" ]]; then
    mount -o $xfs_mount $rootpath /mnt
  elif [[ "$rootfs" = "btrfs" ]]; then
    mount -o $btrfs_mount $rootpath /mnt
  elif [[ "$rootfs" = "f2fs" ]]; then
    mount -o $f2fs_mount $rootpath /mnt
  elif [[ "$rootfs" = "ext4" ]]; then
    mount -o $ext4_mount $rootpath /mnt
  elif [[ "$rootfs" = "jfs" ]]; then
    mount -o $jfs_mount $rootpath /mnt
  fi

  mkdir /mnt/boot
  mount $efipath /mnt/boot

  if [[ "$Aux" = true ]]; then
    mkdir -p /mnt/$AuxUse
    if [[ "$auxfs" = "xfs" ]]; then
      mount -o $xfs_mount $auxpath $AuxUse
    elif [[ "$auxfs" = "btrfs" ]]; then
      mount -o $btrfs_mount $auxpath $AuxUse
    elif [[ "$auxfs" = "f2fs" ]]; then
      mount -o $f2fs_mount $auxpath $AuxUse
    elif [[ "$auxfs" = "ext4" ]]; then
      mount -o $ext4_mount_mount $auxpath $AuxUse
    elif [[ "$auxfs" = "jfs" ]]; then
      mount -o $jfs_mount $auxpath $AuxUse
    fi
  fi

  if [ $recovery -gt 0 ]; then
    mkdir /mnt/RECOVERY
    mount $recoverypath /mnt/RECOVERY
  fi

}

run() {
  # overrides
  # sizes are in Mib
  #ram=$((1*$Gib))
  #disksize=$((8*$Gib))

  echlog "ram(Mib): $ram" $logfile
  echlog "disksize(Mib): $disksize" $logfile
  ramGib=$(($ram / $Gib))
  echlog "ramGib: $ramGib" $logfile
  echlog "------------------------------------" $logfile

  create_partitiontable
  print_partitiontable

  SoftSet $make_table_only false
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
