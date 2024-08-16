#!/bin/bash

# See https://www.qemu.org/docs/master/system/invocation.html?highlight=smbios#hxtool-4
declare -A smb0
declare -A smb1
declare -A smb2
declare -A smb3
declare -A smb4
declare -A smb11
declare -A smb17

# Check if a dmidump file is provided as an argument
DMIDUMP_FILE=""
if [[ -n "$1" && -f "$1" ]]; then
    DMIDUMP_FILE="$1"
fi

# Function to run dmidecode with or without a dmidump file
function runDmidecode () {
    if [[ -n "$DMIDUMP_FILE" ]]; then
        dmidecode --from-dump "$DMIDUMP_FILE" "$@"
    else
        dmidecode --from-dump /tmp/dmi_dump.bin "$@"
    fi
}

function addDmi () {
    declare -n smb="smb$1"
    local dmiDec=$(runDmidecode --string "$3")
    if [[ $? -eq 0 && -n "$dmiDec" ]]; then
        smb[$2]="$dmiDec"
    else
        smb[$2]="Default string"
    fi
}

function addDmiField () {
    declare -n smb="smb$1"
    local dmiDec=$(runDmidecode -t $1 | grep -E "\s$3:" | head -n1 | grep -E -o ':\s+.*$' | cut -c3-)
    if [[ -n "$dmiDec" ]]; then
        smb[$2]="$dmiDec"
    else
        smb[$2]="Default string"
    fi
}

function addStr () {
    declare -n smb="smb$1"
    smb[$2]="$3"
}

function printSmbType () {
    declare -n smb="smb$1"

    echo "<qemu:arg value=\"-smbios\"/>"
    echo -n "<qemu:arg value=\"type=$1"
    for key in "${!smb[@]}"; do
        local val="${smb[$key]/,/,,}"
        if [[ -z "$val" ]]; then val="''"; fi
        echo -n ",$key=$val"
    done
    echo "\"/>"
}

sudo dmidecode --dump-bin /tmp/dmi_dump.bin >> /dev/null

addDmi 0 vendor bios-vendor
addDmi 0 version bios-version
addDmi 0 date bios-release-date
addDmi 0 release bios-revision
addStr 0 uefi on

addDmi 1 manufacturer system-manufacturer
addDmi 1 product system-product-name
addDmi 1 version system-version
addDmi 1 serial system-serial-number
addDmi 1 uuid system-uuid
addDmi 1 sku system-sku-number
addDmi 1 family system-family

addDmi 2 manufacturer baseboard-manufacturer
addDmi 2 product baseboard-product-name
addDmi 2 version baseboard-version
addDmi 2 serial baseboard-serial-number
addDmi 2 asset baseboard-asset-tag
addDmiField 2 location 'Location In Chassis'

addDmi 3 manufacturer chassis-manufacturer
addDmi 3 version chassis-version
addDmi 3 serial chassis-serial-number
addDmi 3 asset chassis-asset-tag
addDmiField 3 sku 'SKU Number'

addDmiField 4 sock_pfx 'Socket Designation'
addDmi 4 manufacturer processor-manufacturer
addDmi 4 version processor-version
addDmiField 4 serial 'Serial Number'
addDmiField 4 asset 'Asset Tag'
addDmi 4 part processor-family

addStr 11 value 'Default string'

addStr 17 loc_pfx 'DIMM 0'
addStr 17 bank 'Bank 0'
addDmiField 17 manufacturer 'Manufacturer'
addDmiField 17 serial 'Serial Number'
addDmiField 17 asset 'Asset Tag'
addDmiField 17 part 'Part Number'
addStr 17 speed 3200

printSmbType 0
printSmbType 1
printSmbType 2
printSmbType 3
printSmbType 4
printSmbType 11
printSmbType 17

echo ''
sudo rm /tmp/dmi_dump.bin
