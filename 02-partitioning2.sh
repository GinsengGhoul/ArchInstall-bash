#! /bin/bash
# public variables
make_recovery=true
increment=1024
# compression levels
min_level=1
max_level=15
ram_path=/ram
# test size in Mib
size=16

# testing overrides
testing=false
#rootpath=/dev/sda3

#functions
# used to find GB number of ram rather then the
# exact number so calculations for swap follow base 2
find_closest() {
  local mem=$1
  # use int division to get a rough estimate
  gib=$((mem / 1024))

  # Check if the input value is slightly above a GiB
  if ((mem % 1024 > 768)); then
    # If so, round up to the next GiB
    gib=$((gib + 1))
  fi
  echo $gib
  return
}

# takes an argument to figure out swap
# the algorithm is to try to use 2x ram
# size for swap unless it is more than
# 1/3 disk size, if it is, it'll try
# 1.25x and 1x, if none of them fit
# it'll go to making no swap partition
set_swap() {
  local third=$(($disksize / 3))
  local ramMib=$(($1 * $increment))
  if [ $(($ramMib * 2)) -le $third ]; then
    swap=$(($ramMib * 2))
  elif [ $(($ramMib * 5 / 4)) -le $third ]; then
    swap=$(($ramMib * 5 / 4))
  elif [ $ramMib -le $third ]; then
    swap=$ramMib
  else
    swap=0
  fi
  return
}

# creates a partition table after swap has been
# set, tests 80 40 and 20gb roots, if the home
# partition ends up being less than 8gb large
# it'll opt to not make a home partition
# in the even the
create_partitiontable() {

  if [ $make_recovery = false ]; then
    if [ $(($disksize - $BB - $EFI - (80 * $increment) - $swap)) -lt $((200 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $swap)) -ge $((8 * $increment)) ] && [ $(($disksize - $BB - $EFI - (80 * $increment) - $swap)) -gt 0 ]; then
      echo "80gb root"
      root=$((80 * $increment))
      home=$(($disksize - $BB - $EFI - $root - $swap))
    elif [ $(($disksize - $EFI - (40 * $increment) - $swap)) -lt $((20 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $swap)) -ge $((8 * $increment)) ] && [ $(($disksize - $BB - $EFI - (40 * $increment) - $swap)) -gt 0 ]; then
      echo "40gb root"
      root=$((40 * $increment))
      home=$(($disksize - $BB - $EFI - $root - $swap))
    elif [ $(($disksize - $EFI - (20 * $increment) - $swap)) -lt $((20 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $swap)) -ge $((8 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $swap)) -gt 0 ]; then
      echo "20gb root"
      root=$((20 * $increment))
      home=$(($disksize - $BB - $EFI - $root - $swap))
    else
      echo "no home"
      root=$(($disksize - $BB - $EFI - $swap))
      home=0
    fi
  # with recovery
  elif [ $make_recovery = true ]; then
    if [ $(($disksize - $BB - $EFI - (80 * $increment) - $recovery - $swap)) -lt $((200 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $recovery - $swap)) -ge $((8 * $increment)) ] && [ $(($disksize - $BB - $EFI - (80 * $increment) - $recovery - $swap)) -gt 0 ]; then
      echo "80gb root"
      root=$((80 * $increment))
      home=$(($disksize - $BB - $EFI - $root - $recovery - $swap))
    elif [ $(($disksize - $EFI - (40 * $increment) - $swap)) -lt $((20 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $swap)) -ge $((8 * $increment)) ] && [ $(($disksize - $BB - $EFI - (40 * $increment) - $recovery - $swap)) -gt 0 ]; then
      echo "40gb root"
      root=$((40 * $increment))
      home=$(($disksize - $BB - $EFI - $root - $recovery - $swap))
    elif [ $(($disksize - $EFI - (20 * $increment) - $recovery - $swap)) -lt $((20 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $recovery - $swap)) -ge $((8 * $increment)) ] && [ $(($disksize - $BB - $EFI - (20 * $increment) - $recovery - $swap)) -gt 0 ]; then
      echo "20gb root"
      root=$((20 * $increment))
      home=$(($disksize - $BB - $EFI - $root - $recovery - $swap))
    else
      echo "no home"
      root=$(($disksize - $BB - $recovery - $EFI - $swap))
      home=0
    fi
  fi
  return
}

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
# n\n\n\n+"$home"M\n8300\n              make home partition
# n\n\n\n+"$recovery"M\n0700\n          make recovery partition
# n\n\n\n+"$swap"M\n\n8200\n            make swap partition
# w\ny\n"                               write table
#
partition_drive() {
  gptstr='o\ny\n'
  bbstr='n\n\n\n+'$BB'M\nef02\n'
  efistr='n\n\n\n+'$EFI'M\nef00\n'
  rootstr='n\n\n\n+'$root'M\n8300\n'
  homestr='n\n\n\n+'$home'M\n8300\n'
  recoverystr='n\n\n\n+'$recovery'M\n0700\n'
  swapstr='n\n\n\n\n+'$swap'M\n8200\n'
  writestr='w\ny\n'

  # for some reason, the last line needs one more enter...

  # start string_builder
  commands=$gptstr$bbstr$efistr$rootstr
  if [ $home -gt 0 ]; then
    commands=$commands$homestr
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
  #commands=$gptstr$bbstr$efistr$rootstr$homestr$recoverystr$swapstr$writestr
  #commands=$gptstr$swapstr$writestr
  #echo $commands
  echo -e $commands | gdisk $disk
  #echo -e $commands
  return
}

format_drive() {
  cp=2                   # dynamic numbers to build partition table
  mkfs.fat -F32 $disk$cp # efi partition
  efipath=$disk$cp
  ((cp++))
  mkfs.btrfs -f -L Arch_Root $disk$cp # root partition
  rootpath=$disk$cp
  ((cp++))
  if [ $home -gt 0 ]; then
    mkfs.btrfs -f -L Arch_Home $disk$cp
    homepath=$disk$cp
    ((cp++))
  fi
  if [ $recovery -gt 0 ]; then
    mkfs.fat -F32 $disk$cp
    ((cp++))
  fi
  if [ $swap -gt 0 ]; then
    mkswap $disk$cp
    swapon $disk$cp
    echo "Swap_UUID=$(blkid -s UUID -o value $disk$cp)" > swap
  else
    echo "Swap_UUID=""" > swap
  fi
}

mksubvol() {
  SUBVOLS=(
    var/log
    var/crash
    var/lib/docker
    var/cache/pacman
    var/spool
    usr/local
    srv
    root
    opt
    .swap # If you need Swapfile, create in this folder
  )
  #the "home" partition is used to store files that will for sure be bigger
  ## don't make a home subvolume if there won't be a home subvolume
  # home
  # var/lib/libvirt/images
  mkdir -p /mnt/@/var/lib
  mkdir -p /mnt/@/var/cache/
  mkdir -p /mnt/@/usr/
  for vol in "${SUBVOLS[@]}"; do
    btrfs subvolume create "/mnt/@/$vol"
    echo "this is "$vol"" >/mnt/@/"$vol"/info
  done
  if [ $home -eq 0 ]; then
    btrfs subvol create /mnt/@/home
    btrfs subvol create /mnt/@/var/lib/libvirt
    echo "this is /var/lib/libvirt" >/mnt/@/var/lib/libvirt/info
    mkdir /mnt/@/var/lib/libvirt/images
    # don't compress or copy on write vm images
    chattr +C /mnt/@/var/lib/libvirt
  fi
  # create snapshot subvol
  btrfs subvolume create /mnt/@/.snapshots
  echo "this is /.snapshots" >/mnt/@/.snapshots/info
  mkdir -p /mnt/@/.snapshots/1
  btrfs subvolume create /mnt/@/.snapshots/1/snapshot
  echo "This is /@/.snapshots/1/snapshot" >/mnt/@/.snapshots/1/snapshot/info
  btrfs subvolume set-default "$(btrfs subvolume list /mnt | grep "@/.snapshots/1/snapshot" | grep -oP '(?<=ID )[0-9]+')" /mnt

  cat <<EOF >>/mnt/@/.snapshots/1/info.xml
<?xml version="1.0"?>
<snapshot>
    <type>single</type>
    <num>1</num>
    <date>2023-01-01 0:00:00</date>
    <description>First Root Filesystem</description>
    <cleanup>number</cleanup>
</snapshot>
EOF

  chmod 600 /mnt/@/.snapshots/1/info.xml
  umount -l /mnt

  if [ $home -gt 0 ]; then
    mount "$homepath" /mnt
    btrfs subvol create /mnt/@
    btrfs subvol create /mnt/@/home
    echo "this is /home  there is a home partition" >/mnt/@/home/info
    mkdir -p /mnt/@/var/lib
    btrfs subvol create /mnt/@/var/lib/libvirt
    echo "this is /var/lib/libvirt  there is a home partition" >/mnt/@/var/lib/libvirt/info
    mkdir /mnt/@/var/lib/libvirt/images
    # don't compress or copy on write vm images
    chattr +C /mnt/@/var/lib/libvirt/images
    umount /mnt
  fi

  # benchmark in .swap subvolume since it's noncow
  mount -o subvol=@/.swap "$rootpath" "/mnt"
  pacman -Sy fio --noconfirm --needed
  get_random_rw_iops
  umount /mnt
  zstd_benchmark
  find_best_compression_level

  if [ $ssd = true ]; then
    mountargs="defaults,noatime,compress-force=zstd:$best_level,discard=async,ssd"
  else
    mountargs="defaults,relatime,autodefrag,compress-force=zstd:$best_level"
  fi

  mount -o "$mountargs" "$rootpath" "/mnt"
  mkdir -p /mnt/boot/efi
  mount $efipath /mnt/boot/efi

  for vol in "${SUBVOLS[@]}"; do
    echo "trying to mount $vol on $rootpath, with these flags: $mountargs"
    mkdir -p "/mnt/$vol"
    mount -o "$mountargs,subvol=@/$vol" "$rootpath" "/mnt/$vol"
  done

  echo "trying to mount .snapshots on $rootpath, with these flags: $mountargs"
  mkdir -p "/mnt/.snapshots"
  mount -o "$mountargs,subvol=@/.snapshots" "$rootpath" "/mnt/.snapshots"

  mkdir -p /mnt/home
  mkdir -p /mnt/var/lib/libvirt
  if [ $home -eq 0 ]; then
    mount -o "$mountargs,subvol=@/home" "$rootpath" "/mnt/home"
    mount -o "$mountargs,subvol=@/var/lib/libvirt" "$rootpath" "/mnt/var/lib/libvirt"
  else
    mount -o "$mountargs,subvol=@/home" "$homepath" "/mnt/home"
    mount -o "$mountargs,subvol=@/var/lib/libvirt" "$homepath" "/mnt/var/lib/libvirt"
  fi
}

kib_to_mib() {
  # Check if input ends with " KiB/s"
  if [[ "$1" == *KiB/s ]]; then
    # Remove " KiB/s" and convert to MiB/s
    echo "$(echo $1 | sed 's/KiB\/s//') / 1024" | bc -l
  else
    echo "$1"
  fi
}

get_random_rw_iops() {
  #local output=$(fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename="$drivepath"random_read_write.fio --bs=4k --iodepth=64 --size="$size"M --readwrite=randrw --rwmixread=80)
  local output=$(fio --randrepeat=1 --ioengine=libaio --gtod_reduce=1 --name=test --filename=/mnt/random_read_write.fio --bs=4k --iodepth=64 --size="$size"M --readwrite=randrw --rwmixread=80)
  local read_iops=$(echo "$output" | grep "read:" | awk '{print $3}' | cut -d"," -f1)
  local write_iops=$(echo "$output" | grep "write:" | awk '{print $3}' | cut -d"," -f1)
  read_speed=$(echo $read_iops | sed 's/BW=//; s/MiB\/s//')
  write_speed=$(echo $write_iops | sed 's/BW=//; s/MiB\/s//')
  read_speed=$(kib_to_mib $read_speed)
  write_speed=$(kib_to_mib $write_speed)
  echo "Random Read : $read_speed"
  echo "Random Write : $write_speed"
  rm /mnt/random_read_write.fio
}

zstd_benchmark() {
  # mount ramfs so it's all in ram
  mkdir $ram_path
  mount ramfs -t ramfs $ram_path
  #rm $input_file $output_file
  # Generate a 1GiB random file in RAM
  #input_file=/dev/shm/input_file
  input_file="$ram_path"/input_file
  #dd if=/dev/urandom of=$input_file bs=1G count=1 iflag=fullblock status=none
  fio --name=test --ioengine=sync --rw=write --bs=1M --numjobs=1 --size="$size"M --buffer_compress_percentage=50 --refill_buffers --buffer_pattern=0xdeadbeef --filename=$input_file
  # Loop through compression levels 1 to 15
  for ((level = $min_level; level <= $max_level; level++)); do
    # Compress the file with the current compression level
    output_file="$ram_path"/output_file.zstd
    compression_start=$(date +%s.%N)
    zstd -$level $input_file -o $output_file
    compression_end=$(date +%s.%N)

    # Calculate the compression speed
    input_size=$(du -b $input_file | cut -f1)
    output_size=$(du -b $output_file | cut -f1)
    compression_time=$(echo "$compression_end - $compression_start" | bc)
    compression_speed=$(echo "scale=2; $input_size / ($compression_time * 1024 * 1024)" | bc)

    # Decompress the file and measure the decompression speed
    decompression_start=$(date +%s.%N)
    zstd -d $output_file -o /dev/null
    decompression_end=$(date +%s.%N)
    decompression_time=$(echo "$decompression_end - $decompression_start" | bc)
    decompression_speed=$(echo "scale=2; $input_size / ($decompression_time * 1024 * 1024)" | bc)

    # Print the results to the console
    printf "Compression level: %s\n" $level
    printf "Input file size: %s bytes\n" $input_size
    printf "Output file size: %s bytes\n" $output_size
    printf "Compression speed: %s MiB/s\n" $compression_speed
    printf "Decompression speed: %s MiB/s\n" $decompression_speed
    printf "\n"

    # Store the results in arrays
    compression_level[$level]=$level
    compression_speed[$level]=$compression_speed
    decompression_speed[$level]=$decompression_speed

    # Remove the input and output files
    #rm $input_file $output_file
    rm $output_file
  done

  rm $input_file
  # Print the results to a file
  for ((level = $min_level; level <= $max_level; level++)); do
    printf "%s %s %s\n" ${compression_level[$level]} ${compression_speed[$level]} ${decompression_speed[$level]}
  done >/zstd_speeds
  # umount ramfs
  umount $ram_path
  rm -r $ram_path
}

find_best_compression_level() {
  # Parse the zstd_speeds file and find the highest compression level that is faster than the disk speeds
  best_level=0
  while read level com_speed decom_speed; do
    echo "$level $com_speed $decom_speed compare $write_speed $read_speed"
    if (($(echo "$com_speed > $write_speed" | bc -l))) && (($(echo "$decom_speed > $read_speed" | bc -l))); then
      best_level=$level
    else
      break
    fi
  done </zstd_speeds

  # Print the result
  echo $best_level
  if [ $best_level -eq 0 ]; then
    best_level=1
  fi
  echo "compression level $best_level"
}

run() {
  if [ $testing = false ]; then
    # returns kibibytes
    # convert to Mb
    ram=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    ram=$(($ram / 1000))
    #returns bytes so convert to Mib
    disksize=$(lsblk -b --output SIZE -n -d $disk)
    disksize=$(($disksize / 1048576))

    # testing overrides
    #ram=$((1*$increment))
    #disksize=$((8*$increment))

    echo "ram(Mib): $ram"
    echo "diskSize(Mib): $disksize"
    local ramGib=$(find_closest $ram)
    # create the partition table sizes in Mib
    # try for 80Gib system, if there isn't
    # more than 200gb for home
    # try for 40Gib system, if the drive isn't
    # large enough space for at least 20Gib home
    # don't make a home partition
    # if the root partition is not at least
    # 10gb of space
    BB=1
    # these are thought of in Gib so convert to Mib
    EFI=$((1 * $increment))
    if [ $make_recovery = false ]; then
      recovery=0
    fi
    if [ $make_recovery = true ]; then
      recovery=$((1 * $increment))
    fi
    # try for 2x swap, if that's more than a third of the
    # disk size, make try smaller sizes till it is less
    # than or equal to a third of it's size
    set_swap $ramGib
    create_partitiontable
    # print partition table
    echo "Bios Boot:      $BB"
    echo "EFI:            $EFI"
    echo "Root:           $root"
    echo "Home:           $home"
    echo "Recovery:       $recovery"
    echo "Swap:           $swap"
    echo "------------------------------------"
    echo "Total           $(($BB + $EFI + $root + $home + $swap + $recovery))"
    echo "lets do it!"
    if [ $(($BB + $EFI + $root + $home + $swap + $recovery)) -eq $disksize ]; then
      echo "these values seem correct"
      partition_drive
    else
      echo "the numbers aren't numbering"
      return 0
    fi
    fdisk -l $disk
    format_drive
    umount -l /mnt
    mount $rootpath /mnt
    mksubvol

  else
    umount -l /mnt
    mount -o subvol=@/.swap "$rootpath" "/mnt"
    #pacman -Sy fio --noconfirm --needed
    get_random_rw_iops
    umount -l /mnt
    #zstd_benchmark
    find_best_compression_level
  fi
}

# the program itself
source Configuration.cfg
run
