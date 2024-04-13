#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_folder> <output_folder>"
    exit 1
fi

input_folder=$1
output_folder=$2

# Check if input folder exists
if [ ! -d "$input_folder" ]; then
    echo "Input folder '$input_folder' does not exist."
    exit 1
fi

# Check if output folder exists, if not, create it
if [ ! -d "$output_folder" ]; then
    mkdir -p "$output_folder"
fi

# Function to convert audio files
convert_audio() {
    local file="$1"
    local output_folder="$2"
    local filename=$(basename -- "$file")
    local extension="${filename##*.}"
    local filename_noext="${filename%.*}"
    local output_file="$output_folder/$filename_noext.mp3"

    if [ "$extension" = "flac" ]; then
        ffmpeg -i "$file" -vn -ar 44100 -ab 128k -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" "$output_file" < /dev/null
    elif [ "$extension" = "mp3" ]; then
        ffmpeg -i "$file" -vn -ar 44100 -ab 128k -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" "$output_file" < /dev/null
    fi

    echo "Converted $filename to $(basename -- "$output_file")"
}

# Function to trap Ctrl+C and terminate script along with all spawned ffmpeg processes
cleanup() {
    echo "Terminating script..."
    pkill -P $$ ffmpeg
    exit 1
}

# Trap Ctrl+C
trap cleanup SIGINT

# Create a temporary file to store the list of files to process
temp_file=$(mktemp)
# Populate the temporary file with the list of files to process
find "$input_folder" -type f -name "*.flac" -o -name "*.mp3" > "$temp_file"

# Get the number of threads to use based on the system's capacity
num_threads=$(( $(nproc) + 2 ))

# Loop to process files
while read -r file; do
    # Check if there are available slots for processing
    while [ $(jobs | wc -l) -ge $num_threads ]; do
        sleep 1
    done

    # Start conversion process in background
    convert_audio "$file" "$output_folder" &
done < "$temp_file"

# Wait for all background processes to finish
wait

# Cleanup temporary file
rm "$temp_file"

echo "Conversion complete."

