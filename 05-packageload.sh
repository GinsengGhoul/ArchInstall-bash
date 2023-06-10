#!/bin/bash
#  video - if you’re nvidia you should be installing xf86-video-nouveau
#          if you’re intel and are using gen4 or older hardware(pre core i series) you should use xf86-video-intel
#          if you are anything newer than that, it’s best to not install xf86-video-intel and use kernel modesetting
#          with the appropriate mesa package:
#              if you are gen7(ivybridge) or older use mesa-amber
#              for all others use the normal mesa, this doesn’t effect amd or nvidia unless you are using
# 		   something VERY VERY ancient
#          if you’re amd you should be installing xf86-video-amdgpu
#  WIFI - if you are using an intel wifi card it may be better to install iw instead of wpa_supplicant
#  video-acceleration -
#				INTEL   - older than broadwell(5th gen intel core i) use libva-intel-driver
# 					    - broadwell and up use intel-media-driver
# 				AMD	    - Radeon R300 to HD 2000 install mesa-vdpau
# 					    - Radeon HD 2000 and up install both mesa-vdpau and libva-mesa-driver
#      NVIDIA	  - if you’re tesla to kepler v2 AND using nouveau
# 					    - install libva-mesa-driver and mesa-vdpau
# 					    - you’ll also need nouveau-fw
# 					    - if you’re using nvidia’s proprietary stuff install nvidia-utils
#               - for Turing and up(16 and 20 series and up) you can nuse
#               - nvidia-open-dkms
#  these are supplimental but not from official repos
#                       - for GMA4500 h264 decoding you’ll want this libva-intel-driver-g45-h264
# 						do note this gpu is literally so weak it probably isn’t worth it
# 	for haswell refresh to skylake vp9 decoding or broadwell to skylake hybrid vp8 decoding
#  	install intel-hybrid-codec-driver
#  reference here: https:# wiki.archlinux.org/title/Hardware_video_acceleration
#  browser - firefox-developer-edition vivaldi opera
#  pick your poison for vivaldi and opera you’ll need to also install
#  vivaldi-ffmpeg-codecs or opera-ffmpeg-codecs along with the original package
#  don’t install dns-over-https if you want native normal dns resolving, or do and mask the service
#
#  you don’t HAVE to use networkmanger, if you could live with just iwctl, systemd-resolv + systemd-networkd or connman you do you
#  however most DEs support networkmanager best so it’s the one I setup
#  for systemd leave networking blank
#
#  bluetooth - install both bluez and bluez-utils if you want bluetooth, I am content with using bluetoothctl
#  in terminal however if you want a GUI there’s blueman or blueberry.  Blueberry comes from cinnamon so
#  if you want to choose cinnamon as your DE you don’t need to install either of these, KDE and gnome also
#  come with one installed
snapper="snapper snap-pac snap-sync"
security="apparmor"
optimizations="irqbalance ananicy-cpp chrony"
compilier_optimizations="ccache"
computer_signals="acpid tlp"
git="git curl wget rsync"
ssh="dropbear samba"
mesa="mesa-amber lib32-mesa-amber"
video_3d="vulkan-intel vulkan-mesa-layers lib32-vulkan-mesa-layers"
video_acceleration="libva-intel-driver"
networking="networkmanager dhcpcd dnsmasq firewalld"
wifi="iw"
browser="firefox-developer-edition"
bluetooth="bluetooth-support"
editor="neovim"
fstools="gdisk ntfs-3g dosfstools exfatprogs btrfs-progs mtools"
fonts="noto-fonts noto-fonts-cjk ttf-joypixels noto-fonts-extra ttf-ibm-plex"
KVM="qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat ebtables iptables-nft libguestfs edk2-ovmf swtpm"
pdf="okular"
# jre
java="jre-openjdk"
java8="jre8-openjdk"
java11="jre11-openjdk"
java17="jre17-openjdk"
# jdk openjfx requires aur
javaJDK="jdk-openjdk java-openjfx"
java8JDK="jdk8-openjdk java8-openjfx"
java11JDK="jdk11-openjdk java11-openjfx"
java17JDK="jdk17-openjdk java17-openjfx"
java_management="java-runtime-common"
openfonts="ttf-caladea ttf-carlito ttf-dejavu ttf-liberation ttf-linux-libertine-g noto-fonts adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts"
openfontsAUR="ttf-gentium-basic"
libreoffice="libreoffice-fresh libreoffice-extension-texmaths libreoffice-extension-writer2latex hunspell hunspell-en_us libmythes mythes-en $openfonts $java"
libreofficeAUR="libreoffice-extension-languagetool $java8"
# aur only
nativeMS="fake-ms-fonts"
MSfonts="ttf-ms-fonts ttf-tahoma ttf-vista-fonts"

variables=(
  snapper security optimizations compilier_optimizations computer_signals git ssh mesa video_3d video_acceleration networking wifi browser bluetooth editor fstools fonts KVM pdf java java8 java11 java17 javaJDK java8JDK java11JDK java17JDK java_management openfonts openfontsAUR libreoffice libreofficeAUR nativeMS MSfonts
)

install_DE() {
  case "$DE" in
  "Deepin")
    powerpill_command xorg lightdm lightdm-gtk-greeter deepin deepin-extra deepin-kwin
    arch-chroot /mnt systemctl enable lightdm.service
    ;;
  "KDE")
    powerpill_command xorg plasma kde-graphics-meta kde-system-meta kde-utilities-meta breeze-gtk
    arch-chroot /mnt systemctl enable sddm.service
    ;;
  "KDE-wayland")
    powerpill_command wayland plasma kde-graphics-meta kde-system-meta kde-utilities-meta breeze-gtk plasma-wayland-session
    arch-chroot /mnt systemctl enable sddm.service
    ;;
  "Cinnamon")
    powerpill_command xorg lightdm lightdm-slick-greeter cinnamon gnome-terminal file-roller xed xreader gnome-calculator gnome-font-viewer gnome-screenshot xdg-utils gvfs-mtp gvfs-gphoto2 gvfs-afc
    AUR_command xviewer pix mint-artwork lightdm-settings
    arch-chroot /mnt systemctl enable lightdm.service
    ;;
  "Mate")
    powerpill_command xorg lightdm lightdm-gtk-greeter mate mate-extra pipewire pipewire-alsa pipewire-pulse wireplumber network-manager-applet gtk-engines gtk-engine-murrine
    arch-chroot /mnt systemctl enable lightdm.service
    ;;
  "XFCE")
    powerpill_command xorg lightdm lightdm-gtk-greeter xfce4 xfce4-goodies alacarte file-roller gnome-calculator gvfs gvfs-afc gvfs-mtp gvfs-gphoto2 pipewire pipewire-alsa pipewire-pulse network-manager-applet pavucontrol
    arch-chroot /mnt systemctl enable lightdm.service
    ;;
  "LXDE")
    powerpill_command xorg lxde xdg-utils libpulse libstatgrab libsysstat breeze-icons pulseaudio pulseaudio-bluetooth pulseaudio-alsa gnome-calculator file-roller picom
    AUR_command nm-tray
    arch-chroot /mnt systemctl enable lxdm.service
    ;;
  "LXQT")
    powerpill_command xorg sddm lxqt xdg-utils libpulse libstatgrab libsysstat breeze-icons pulseaudio pulseaudio-bluetooth pulseaudio-alsa gnome-calculator file-roller picom
    AUR_command nm-tray opensnap
    arch-chroot /mnt systemctl enable sddm.service
    ;;
  "icewm")
    powerpill_command xorg lightdm lightdm-gtk-greeter icewm network-manager-applet notification-daemon xscreensaver lxsession volumeicon gvfs gvfs-afc gvfs-mtp gvfs-gphoto2 pulseaudio pulseaudio-bluetooth pulseaudio-alsa gnome-calculator file-roller
    arch-chroot /mnt systemctl enable lightdm.service
    ;;
  "i3")
    powerpill_command xorg lightdm lightdm-gtk-greeter I3-wm rofi feh alacritty deadd-notification-center-git playerctl breeze qt5tc xclip
    arch-chroot /mnt systemctl enable lightdm.service
    ;;
  "sway")
    powerpill_command sway polkit wofi swaylock-effects swayidle swaybg alacritty mako sddm okular grim wl-clipboard thunar gvfs gvfs-afc gvfs-gphoto2 gvfs-mtp man brightnessctl pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol adapta-gtk-theme papirus-icon-theme qt6-wayland qt5-wayland slurp file-roller p7zip unrar unace lrzip squashfs-tools qt5ct lxappearance gnome-font-viewer mpv
    arch-chroot /mnt systemctl enable sddm.service
    cat <<EOF >/mnt/etc/profile.d/qt5ct.sh
#export QT_QPA_PLATFORMTHEME=qt5ct
export QT_QPA_PLATFORMTHEME=qt6ct
#export QT_STYLE_OVERRIDE=qt6ct qtapp
#export QT_QPA_PLATFORMTHEME=adwaita-dark
export QT_STYLE_OVERRIDE=adwaita-dark qtapp
EOF
    chmod 755 /mnt/etc/profile.d/qt5ct.sh
    ;;
  *)
    echo "no Desktop Enviroment will be installed"
    ;;
  esac
}

soft_set() {
  local variable_name="$1"
  local value="$2"

  if [ -z "${!variable_name}" ]; then
    eval "$variable_name=$value"
    echo "Variable '$variable_name' set to '$value'"
  else
    echo "Variable '$variable_name' is already set, not changing its value"
  fi
}

set_template_packages() {
  case "$ArchInstallType" in
  "laptop")
    soft_set install_snapper "true"
    soft_set install_security "true"
    soft_set install_optimizations "true"
    soft_set install_compilier_optimizations "true"
    soft_set install_computer_signals "true"
    soft_set install_git "true"
    soft_set install_ssh "false"
    soft_set install_mesa "true"
    soft_set install_video "true"
    soft_set install_video_3d "true"
    soft_set install_video_acceleration "true"
    soft_set install_networking "true"
    soft_set install_wifi "true"
    soft_set install_browser "true"
    soft_set install_bluetooth "true"
    soft_set install_editor "true"
    soft_set install_fstools "false"
    soft_set install_fonts "true"
    soft_set install_pdf "true"
    soft_set install_java "true"
    soft_set install_java_management "true"
    soft_set install_java "false"
    soft_set install_java8 "false"
    soft_set install_java11 "false"
    soft_set install_java17 "false"
    soft_set install_javaJDK "true"
    soft_set install_java8JDK "false"
    soft_set install_java17JDK "false"
    soft_set install_java11JDK "false"
    soft_set install_openfonts "true"
    soft_set install_openfontsAUR "true"
    soft_set install_libreoffice "true"
    soft_set install_libreofficeAUR "true"
    soft_set install_nativeMS "false"
    soft_set install_MSfonts "true"
    ;;
  "desktop")
    soft_set install_snapper "true"
    soft_set install_security "true"
    soft_set install_optimizations "true"
    soft_set install_compilier_optimizations "true"
    soft_set install_computer_signals "false"
    soft_set install_git "true"
    soft_set install_ssh "false"
    soft_set install_mesa "true"
    soft_set install_video "true"
    soft_set install_video_3d "true"
    soft_set install_video_acceleration "true"
    soft_set install_networking "true"
    soft_set install_wifi "true"
    soft_set install_browser "true"
    soft_set install_bluetooth "true"
    soft_set install_editor "true"
    soft_set install_fstools "false"
    soft_set install_fonts "true"
    soft_set install_pdf "true"
    soft_set install_java "true"
    soft_set install_java_management "true"
    soft_set install_java "false"
    soft_set install_java8 "false"
    soft_set install_java11 "false"
    soft_set install_java17 "false"
    soft_set install_javaJDK "true"
    soft_set install_java8JDK "false"
    soft_set install_java17JDK "false"
    soft_set install_java11JDK "false"
    soft_set install_openfonts "true"
    soft_set install_openfontsAUR "true"
    soft_set install_libreoffice "true"
    soft_set install_libreofficeAUR "true"
    soft_set install_nativeMS "false"
    soft_set install_MSfonts "true"
    ;;
  "server")
    soft_set install_snapper "false"
    soft_set install_security "true"
    soft_set install_optimizations "false"
    soft_set install_compilier_optimizations "true"
    soft_set install_computer_signals "false"
    soft_set install_git "true"
    soft_set install_ssh "true"
    soft_set install_mesa "false"
    soft_set install_video "false"
    soft_set install_video_3d "false"
    soft_set install_video_acceleration "false"
    soft_set install_networking "false"
    soft_set install_wifi "false"
    soft_set install_browser "false"
    soft_set install_bluetooth "false"
    soft_set install_editor "true"
    soft_set install_fstools "false"
    soft_set install_fonts "false"
    soft_set install_pdf "false"
    soft_set install_java "true"
    soft_set install_java_management "true"
    soft_set install_java "false"
    soft_set install_java8 "false"
    soft_set install_java11 "false"
    soft_set install_java17 "false"
    soft_set install_javaJDK "true"
    soft_set install_java8JDK "false"
    soft_set install_java17JDK "false"
    soft_set install_java11JDK "false"
    soft_set install_openfonts "false"
    soft_set install_openfontsAUR "false"
    soft_set install_libreoffice "false"
    soft_set install_libreofficeAUR "false"
    soft_set install_nativeMS "false"
    soft_set install_MSfonts "false"
    DE="none"
    ;;
  *) ;;
  esac
}

set_packages() {
  packages=""
  AUR_packages=""

  for variable in "${variables[@]}"; do
    local install_variable="install_$variable"
    local package_variable="$variable"

    if [[ "${!install_variable}" == "true" ]]; then
      if [[ "${package_variable: -3}" == "AUR" || "$variable" == "MSfonts" || "$variable" == "nativeMS" ]]; then
        AUR_packages+=" ${!package_variable}"
      else
        packages+=" ${!package_variable}"
      fi
    fi
  done

  #echo "Packages: $packages"
  #echo "AUR Packages: $AUR_packages"
}

run() {
  set_template_packages
  set_packages
  echo "Packages: $packages"
  echo "AUR Packages: $AUR_packages"
  powerpill_command "$packages"
  AUR_command $aurpkgs
  install_DE
}

source Configuration.cfg
run
