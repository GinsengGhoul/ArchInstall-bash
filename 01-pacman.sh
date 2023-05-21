#! /bin/bash
# Gordon Teh 3/21/23
# 

mirror_url="https://mirror.cachyos.org/repo/x86_64/cachyos"

check_supported_isa_level() {
    SupportLevel=0
    if grep x86-64-v4 /supportedlist
    then SupportLevel=4
    fi
    if grep x86-64-v3 /supportedlist
    then
      if [ $SupportLevel -lt 3 ]
      then SupportLevel=3
      fi
    fi
    if grep x86-64-v2 /supportedlist
    then
      if [ $SupportLevel -lt 2 ]
      then SupportLevel=2
      fi
    else SupportLevel=1
    fi
}

check_if_repo_was_added() {
  # this will simply look in pacman.conf for anything cachyos related
  # so if anything shows up this is true
  # if grep "(cachyos\|cachyos-v3\|cachyos-community-v3\|cachyos-v4)" /etc/pacman.conf
  if grep -e cachyos -e cachyos-v3 -e cachyos-community-v3 -e cachyos-v4 /etc/pacman.conf
    then
      added=1
    else
      added=0
    fi
    clear
}

check_if_repo_was_commented() {
  # this will first look for anything related to cachyOS
  # then it'll slowly weed out anything with comments
  # if there is anything left is outputed by grep, it's not commented
  if grep "cachyos\|cachyos-v3\|cachyos-community-v3\|cachyos-v4" /etc/pacman.conf | grep -v "#\[" | grep "\["
  then
    commented=0
  else
    commented=1
  fi
  clear
}

add_repos() {
  # This builds a repo list, originally was going to use sed to put it
  # in a nice place like under #[testing] however, couldn't get that
  # to work so have 3 if statments instead
  if [ $SupportLevel -ge 1 ]
  then
    sed -i --posix '/after the header/a\\n[cachyos]\nInclude = \/etc\/pacman.d\/cachyos-mirrorlist' /etc/pacman.conf
  fi
  if [ $SupportLevel -ge 3 ]
  then
    sed -i --posix '/after the header/a\\n[cachyos-v3]\nInclude = \/etc\/pacman.d\/cachyos-v3-mirrorlist\n\n[cachyos-community-v3]\nInclude = \/etc\/pacman.d\/cachyos-v3-mirrorlist' /etc/pacman.conf
  fi
  if [ $SupportLevel -ge 4 ]
  then
    sed -i --posix '/after the header/a\\n[cachyos-v4]\nInclude = \/etc\/pacman.d\/cachyos-v4-mirrorlist' /etc/pacman.conf
  fi
}

install_mirrorlists() {
    if [ $SupportLevel -eq 4 ]
    then
      pacman -U "${mirror_url}/cachyos-keyring-2-1-any.pkg.tar.zst"        \
                "${mirror_url}/cachyos-mirrorlist-17-1-any.pkg.tar.zst"    \
                "${mirror_url}/cachyos-v3-mirrorlist-17-1-any.pkg.tar.zst" \
                "${mirror_url}/cachyos-v4-mirrorlist-5-1-any.pkg.tar.zst"  \
                --noconfirm
    fi
    if [ $SupportLevel -eq 3 ]
    then
      pacman -U "${mirror_url}/cachyos-keyring-2-1-any.pkg.tar.zst"        \
                "${mirror_url}/cachyos-mirrorlist-17-1-any.pkg.tar.zst"    \
                "${mirror_url}/cachyos-v3-mirrorlist-17-1-any.pkg.tar.zst" \
                --noconfirm
    fi
    if [ $SupportLevel -le 2 ]
    then
      pacman -U "${mirror_url}/cachyos-keyring-2-1-any.pkg.tar.zst"        \
                "${mirror_url}/cachyos-mirrorlist-17-1-any.pkg.tar.zst"    \
                --noconfirm
    fi
}

run() {
    /lib/ld-linux-x86-64.so.2 --help | grep "(supported, searched)" > /supportedlist
    check_supported_isa_level
    check_if_repo_was_added
    check_if_repo_was_commented
    echo "SupportLevel = $SupportLevel"
    printf "Your CPU supports: "
       printf "Your CPU supports: "
    if [ $SupportLevel -ge 4 ]
    then
      printf "x86-64-v4 "
    fi
    if [ $SupportLevel -ge 3 ]
    then
      printf "x86-64-v3 "
    fi
    if [ $SupportLevel -ge 2 ]
    then
      printf "x86-64-v2 "
    fi
    if [ $SupportLevel -ge 1 ]
    then
      printf "x86-64 "
    fi 
    if [ $SupportLevel -ge 4 ]
    then
      printf "x86-64-v4 "
    fi
    if [ $SupportLevel -ge 3 ]
    then
      printf "x86-64-v3 "
    fi
    if [ $SupportLevel -ge 2 ]
    then
      printf "x86-64-v2 "
    fi
    if [ $SupportLevel -ge 1 ]
    then
      printf "x86-64 "
    fi
    echo ""
    #echo "commented = $commented"
    #echo "added = $added"
    if [ $added -eq 0 ]
    then
      echo "initalize pacmankey"
      pacman-key --init
      echo "Update ArchLinux-keyring"
      pacman -Sy archlinux-keyring --noconfirm
      echo "importing CachyOS key"
      pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
      pacman-key --lsign-key F3B607488DB35A47
     echo "installing CachyOS keyring and mirrorlists"
      install_mirrorlists
      echo "Adding CachyOS repos ..."
      add_repos
      echo "finish setting up pacman.conf"
      # uncomment colors
      sed -i '/Color/s/^#//g' /etc/pacman.conf
      # uncomment Parallel Downloads
      sed -i '/ParallelDownloads/s/^#//g' /etc/pacman.conf
      # uncomment multilib(32bit binaries)
      sed -i '/#\[multilib\]/s/^#//' /etc/pacman.d/mirrorlist
      sed -i '/#Include = \/etc\/pacman\.d\/mirrorlist/s/^#//' /etc/pacman.d/mirrorlist
      # update mirrorlists for faster update
      echo "updating for fastest mirrors"
      reflector -c "US" -f 12 -l 10 -n 12 --save /etc/pacman.d/mirrorlist
      # update packages
      echo "update packages"
      pacman -Sy pacman --noconfirm
    elif [ $added -eq 1 ]
    then
      if [ $commented -eq 1 ]
      then
        echo "You've already added the CachyOS repos but they are commented"
      else
      echo "You've already added the CachyOS repos!"
      fi
    fi
    # cat /etc/pacman.conf
    rm /supportedlist
}

run
