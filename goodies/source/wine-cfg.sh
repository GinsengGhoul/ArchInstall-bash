#!/bin/bash

# Function to update key-value pairs in a config file
update_config() {
    local config_file=$1
    local key=$2
    local value=$3
    if grep -q "^$key=" "$config_file"; then
        sed -i "s/^$key=.*/$key=\"$value\"/" "$config_file"
    else
        echo "$key=\"$value\"" >> "$config_file"
    fi
}

# Function to prepend GCC flags to a specified key in a config file
prepend_gcc_flags() {
    local config_file=$1
    local key=$2
    local gcc_flags=$3
    if grep -q "^$key=" "$config_file"; then
        sed -i "s|^$key=\"\(.*\)\"|$key=\"$gcc_flags \1\"|" "$config_file"
    else
        echo "$key=\"$gcc_flags -O2\"" >> "$config_file"
    fi
}

update_ld_flags() {
    local config_file=$1
    local key=$2
    local value=$3
    if grep -q "^$key=" "$config_file"; then
        sed -i "s/^$key=\"[^\"]*\"/$key=\"$value\"/" "$config_file"
    else
        echo "$key=\"$value\"" >> "$config_file"
    fi
}

# Check if the path to wine-tkg-git is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_wine-tkg-git>"
    exit 1
fi

WINE_TKG_GIT_PATH=$1

# Paths to configuration files
PROTON_CONFIG_FILE="$WINE_TKG_GIT_PATH/proton-tkg/proton-tkg.cfg"
PROTON_ADVANCED_CONFIG_FILE="$WINE_TKG_GIT_PATH/proton-tkg/proton-tkg-profiles/advanced-customization.cfg"
WINE_CONFIG_FILE="$WINE_TKG_GIT_PATH/wine-tkg-git/customization.cfg"
WINE_ADVANCED_CONFIG_FILE="$WINE_TKG_GIT_PATH/wine-tkg-git/wine-tkg-profiles/advanced-customization.cfg"

# Set plain version, use staging, and staging version
# https://github.com/wine-mirror/wine/commits/master
_PLAIN_VERSION=""
_USE_STAGING="true"
# https://github.com/wine-staging/wine-staging/commits/master
_STAGING_VERSION=""

# Update the settings in proton-tkg configuration files
update_config "$PROTON_CONFIG_FILE" "_plain_version" "$_PLAIN_VERSION"
update_config "$PROTON_CONFIG_FILE" "_use_staging" "$_USE_STAGING"
update_config "$PROTON_CONFIG_FILE" "_staging_version" "$_STAGING_VERSION"

# Update the settings in wine-tkg-git customization.cfg
update_config "$WINE_CONFIG_FILE" "_plain_version" "$_PLAIN_VERSION"
update_config "$WINE_CONFIG_FILE" "_use_staging" "$_USE_STAGING"
update_config "$WINE_CONFIG_FILE" "_staging_version" "$_STAGING_VERSION"

# Set values in proton-tkg.cfg
update_config "$PROTON_CONFIG_FILE" "_LOCAL_PRESET" "none"
update_config "$PROTON_CONFIG_FILE" "_use_josh_flat_theme" "false"
update_config "$PROTON_CONFIG_FILE" "_FS_bypass_compositor" "true"
update_config "$PROTON_CONFIG_FILE" "_proton_fs_hack" "true"
update_config "$PROTON_CONFIG_FILE" "_win10_default" "true"
update_config "$PROTON_CONFIG_FILE" "_protonify" "true"

# Set values in wine-tkg-git/customization.cfg
update_config "$WINE_CONFIG_FILE" "_LOCAL_PRESET" "none"
update_config "$WINE_CONFIG_FILE" "_use_josh_flat_theme" "false"
update_config "$WINE_CONFIG_FILE" "_FS_bypass_compositor" "true"
update_config "$WINE_CONFIG_FILE" "_proton_fs_hack" "true"
update_config "$WINE_CONFIG_FILE" "_win10_default" "true"
update_config "$WINE_CONFIG_FILE" "_protonify" "true"

# Get GCC flags
GCC_FLAGS=$(gcc -### -E -x c /dev/null -march=native 2>&1 | grep 'cc1' | sed -E 's/.*cc1.*-E -quiet \/dev\/null//;s/-dumpbase.*//;s/"//g')
#GCC_FLAGS="-march=x86-64-v4 -mtune=generic"
#GCC_FLAGS="-march=x86-64-v3 -mtune=generic"
#GCC_FLAGS="-march=x86-64-v2 -mtune=generic"
#GCC_FLAGS="-march=x86-64 -mtune=generic"

# Prepend GCC flags to advanced-customization.cfg
prepend_gcc_flags "$PROTON_ADVANCED_CONFIG_FILE" "_CROSS_FLAGS" "$GCC_FLAGS"
prepend_gcc_flags "$PROTON_ADVANCED_CONFIG_FILE" "_GCC_FLAGS" "$GCC_FLAGS"
prepend_gcc_flags "$WINE_ADVANCED_CONFIG_FILE" "_CROSS_FLAGS" "$GCC_FLAGS"
prepend_gcc_flags "$WINE_ADVANCED_CONFIG_FILE" "_GCC_FLAGS" "$GCC_FLAGS"

# Update LD_FLAGS and CROSS_LD_FLAGS in advanced-customization.cfg
_LD_FLAGS="-Wl,-O2,--sort-common,--as-needed"
update_ld_flags "$PROTON_ADVANCED_CONFIG_FILE" "_LD_FLAGS" "$_LD_FLAGS"
update_ld_flags "$PROTON_ADVANCED_CONFIG_FILE" "_CROSS_LD_FLAGS" "$_LD_FLAGS"
update_ld_flags "$WINE_ADVANCED_CONFIG_FILE" "_LD_FLAGS" "$_LD_FLAGS"
update_ld_flags "$WINE_ADVANCED_CONFIG_FILE" "_CROSS_LD_FLAGS" "$_LD_FLAGS"

echo "Configuration files updated successfully."

