#! /bin/bash
min_level=1
max_level=15
drive_path=/root/
ram_path=/ram
# size in Mib
size=16

kib_to_mib() {
  # Check if input ends with " KiB/s"
  if [[ "$1" == *KiB/s ]]; then
    # Remove " KiB/s" and convert to MiB/s
    echo "$(echo $1 | sed 's/ KiB\/s//') / 1024" | bc -l
  else
    echo "$1"
  fi
}


get_random_rw_iops() {
    local output=$(fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename="$drivepath"random_read_write.fio --bs=4k --iodepth=64 --size="$size"M --readwrite=randrw --rwmixread=80)
    local read_iops=$(echo "$output" | grep "read:" | awk '{print $3}' | cut -d"," -f1)
    local write_iops=$(echo "$output" | grep "write:" | awk '{print $3}' | cut -d"," -f1)
    read_speed=$(echo $read_iops | sed 's/BW=//; s/MiB\/s//')
    write_speed=$(echo $write_iops | sed 's/BW=//; s/MiB\/s//')
    # this will catch if the drive is replying in KiB/s
    read_speed=$(kib_to_mib $read_speed)
    write_speed=$(kib_to_mib $write_iops)
    echo "Random Read : $read_speed"
    echo "Random Write : $write_speed"
    rm random_read_write.fio
}

zstd_benchmark() {
  #rm $input_file $output_file
  # Generate a 1GiB random file in RAM
  #input_file=/dev/shm/input_file
  input_file="$ram_path"/input_file
  #dd if=/dev/urandom of=$input_file bs=1G count=1 iflag=fullblock status=none
  fio --name=test --ioengine=sync --rw=write --bs=1M --numjobs=1 --size="$size"M --buffer_compress_percentage=50 --refill_buffers --buffer_pattern=0xdeadbeef --filename=$input_file
  # Loop through compression levels 1 to 15
  for ((level=$min_level; level<=$max_level; level++))
  do
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
  for ((level=$min_level; level<=$max_level; level++))
  do
    printf "%s %s %s\n" ${compression_level[$level]} ${compression_speed[$level]} ${decompression_speed[$level]}
  done > /zstd_speeds
}

function find_best_compression_level() {
    # Parse the zstd_speeds file and find the highest compression level that is faster than the disk speeds
    best_level=0
    while read level com_speed decom_speed; do
      echo "$level $com_speed $decom_speed compare $write_speed $read_speed"
        if (( $(echo "$com_speed > $write_speed" | bc -l) )) && (( $(echo "$decom_speed > $read_speed" | bc -l) )); then
            best_level=$level
        else
            break
        fi
    done < zstd_speeds

    # Print the result
    echo $best_level
}


run(){
  #pacman -Sy fio --noconfirm --needed
  #mkdir -p $ram_path
  #mount ramfs -t ramfs $ram_path
  #zstd_benchmark
  get_random_rw_iops
  #find_best_compression_level 
  #umount $ram_path
  #rm -r $ram_path
}

run

