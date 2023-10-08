#! /bin/bash
# Gordon Teh 3/21/23
#

#mirror_url="https://mirror.cachyos.org/repo/x86_64/cachyos/"
mirror_url="https://aur.cachyos.org/repo/x86_64/cachyos/"

logfile="Pacman.log"

check_supported_isa_level() {
  SupportLevel=0
  if grep x86-64-v4 /supportedlist; then
    SupportLevel=4
  fi
  if grep x86-64-v3 /supportedlist; then
    if [ $SupportLevel -lt 3 ]; then
      SupportLevel=3
    fi
  fi
  if grep x86-64-v2 /supportedlist; then
    if [ $SupportLevel -lt 2 ]; then
      SupportLevel=2
    fi
  else
    SupportLevel=1
  fi
}

add_repos() {
  # This builds a repo list, originally was going to use sed to put it
  # in a nice place like under #[testing] however, couldn't get that
  # to work so have 3 if statments instead
  if [ $SupportLevel -ge 1 ]; then
    sed -i --posix '/after the header/a\\n[cachyos]\nInclude = \/etc\/pacman.d\/cachyos-mirrorlist' /etc/pacman.conf
  fi
  if [ $SupportLevel -ge 3 ]; then
    sed -i --posix '/after the header/a\\n[cachyos-v3]\nInclude = \/etc\/pacman.d\/cachyos-v3-mirrorlist\n\n[cachyos-community-v3]\nInclude = \/etc\/pacman.d\/cachyos-v3-mirrorlist' /etc/pacman.conf
  fi
  if [ $SupportLevel -ge 4 ]; then
    sed -i --posix '/after the header/a\\n[cachyos-v4]\nInclude = \/etc\/pacman.d\/cachyos-v4-mirrorlist' /etc/pacman.conf
  fi
}

add_xyne_repo() {
  # Download the mirrorlist file
  curl -o /etc/pacman.d/xyne-mirrorlist https://xyne.dev/projects/xyne-mirrorlist/xyne-mirrorlist
  cat <<EOF >>/etc/pacman.conf

[xyne-x86_64]
SigLevel = Required
Include = /etc/pacman.d/xyne-mirrorlist
EOF
}

download_and_install_packages() {
  local packages=("$@")

  # Extract package URLs from the webpage
  webpage_content=$(curl -s "$mirror_url")
  for package in "${packages[@]}"; do
    # Try to find the package URL based on its title
    package_filename=$(echo "$webpage_content" | grep -oE 'href=([^ ]+)' | cut -d'=' -f2)

    if [ -z "$package_filename" ]; then
      echo "Package '$package' not found on the webpage."
    else
      # Download the package and its signature
      package_signature="${package_filename}.sig"

      wget "$mirror_url$package_filename"
      wget "$mirror_url$package_signature"

      # Verify the package signature
      pacman-key --verify "$package_signature

      if [ $? -eq 0 ]; then
        echlog "$package_filename"
        # Install the package using pacman
        sudo pacman -U "$package_filename" --noconfirm
      else
        echo "Package signature verification failed for '$package'."
      fi
    fi
  done
}

run() {
  /lib/ld-linux-x86-64.so.2 --help | grep "(supported, searched)" >supportedlist
  check_supported_isa_level

  echlog "SupportLevel = $SupportLevel"
  echo ""
  printf "Your CPU supports: "
  if [ $SupportLevel -ge 4 ]; then
    printf "x86-64-v4 "
  fi
  if [ $SupportLevel -ge 3 ]; then
    printf "x86-64-v3 "
  fi
  if [ $SupportLevel -ge 2 ]; then
    printf "x86-64-v2 "
  fi
  if [ $SupportLevel -ge 1 ]; then
    printf "x86-64 "
  fi
  echo ""

  #echo "commented = $commented"
  #echo "added = $added"
  echo "initalize pacmankey"
  pacman-key --init
  echo "Update ArchLinux-keyring"
  pacman -Sy archlinux-keyring --noconfirm
  echo "importing CachyOS key"
  pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
  pacman-key --lsign-key F3B607488DB35A47
  echo "installing CachyOS keyring and mirrorlists"
  wget "$mirror_url"cachyos.db
  wget "$mirror_url"cachyos.db.sig
  pacman-key --verify cachyos.db.sig
  download_and_install_packages "cachyos-keyring" "cachyos-mirrorlist" "cachyos-v3-mirrorlist" "cachyos-v4-mirrorlist"
  echo "Adding CachyOS repos ..."
  add_repos
  echo "Adding xyne repos ..."
  add_xyne_repo
  echo "finish setting up pacman.conf"
  # uncomment colors
  sed -i '/Color/s/^#//g' /etc/pacman.conf
  # uncomment Parallel Downloads
  sed -i '/ParallelDownloads/s/^#//g' /etc/pacman.conf
  # uncomment multilib(32bit binaries)
  sed -i '/#\[multilib\]/s/^#//' /etc/pacman.conf
  sed -i '/#Include = \/etc\/pacman\.d\/mirrorlist/s/^#//' /etc/pacman.conf
  # update mirrorlists for faster update
  echo "updating for fastest mirrors"
  reflector -c "US" -f 12 -l 10 -n 12 --save /etc/pacman.d/mirrorlist
  # update packages
  echo "update packages"
  pacman -Sy pacman cachyos-keyring --noconfirm
  # cat /etc/pacman.conf
}

run
