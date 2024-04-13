#!/bin/bash
logfile="Packages.log"
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
    powerpill_command wayland plasma kde-graphics-meta kde-system-meta kde-utilities-meta breeze-gtk plasma-wayland-session
    arch-chroot /mnt systemctl enable sddm.service
    ;;
  "KDE-xorg")
    powerpill_command xorg plasma kde-graphics-meta kde-system-meta kde-utilities-meta breeze-gtk
    arch-chroot /mnt systemctl enable sddm.service
    ;;
  "Cinnamon")
    powerpill_command xorg lightdm lightdm-slick-greeter cinnamon gnome-terminal file-roller xed xreader gnome-calculator gnome-font-viewer gnome-screenshot xdg-utils gvfs-mtp gvfs-gphoto2 gvfs-afc hicolor-icon-theme
    AUR_command xviewer pix mint-themes mint-x-icons mint-y-icons lightdm-settings
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /mnt/etc/lightdm/lightdm.conf
    arch-chroot /mnt systemctl enable lightdm.service
    ;;
  "Cinnamon-noAUR")
    powerpill_command xorg lightdm lightdm-gtk-greeter cinnamon gnome-terminal file-roller xed xreader gnome-calculator gnome-font-viewer gnome-screenshot xdg-utils gvfs-mtp gvfs-gphoto2 gvfs-afc loupe gthumb breeze
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
    SoftSet rootfs "btrfs"
    if [[ "$rootfs" = "btrfs" ]]; then
      soft_set install_snapper "false"
    else
      # if your rootfs isn't btrfs you should never have any of the snapper stuff
      install_snapper="false"
    fi
    soft_set install_security "true"
    soft_set install_optimizations "true"
    soft_set install_computer_signals "true"
    soft_set install_git "true"
    soft_set install_ssh "false"
    soft_set install_mesa "true"
    soft_set install_xorg_drivers "true"
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
    soft_set install_java8 "false"
    soft_set install_java11 "false"
    soft_set install_java17 "false"
    soft_set install_javaJDK "true"
    soft_set install_java8JDK "false"
    soft_set install_java11JDK "false"
    soft_set install_java17JDK "false"
    soft_set install_java_management "true"
    soft_set install_openfonts "true"
    soft_set install_openfontsAUR "true"
    soft_set install_libreoffice "true"
    soft_set install_libreofficeAUR "true"
    soft_set install_nativeMS "false"
    soft_set install_MSfonts "true"
    ;;
  "desktop")
    SoftSet rootfs "btrfs"
    if [[ "$rootfs" = "btrfs" ]]; then
      soft_set install_snapper "false"
    else
      # if your rootfs isn't btrfs you should never have any of the snapper stuff
      install_snapper="false"
    fi
    soft_set install_security "true"
    soft_set install_optimizations "true"
    soft_set install_computer_signals "false"
    soft_set install_git "true"
    soft_set install_ssh "false"
    soft_set install_mesa "true"
    soft_set install_xorg_drivers "true"
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
    soft_set install_java8 "false"
    soft_set install_java11 "false"
    soft_set install_java17 "false"
    soft_set install_javaJDK "true"
    soft_set install_java8JDK "false"
    soft_set install_java11JDK "false"
    soft_set install_java17JDK "false"
    soft_set install_java_management "true"
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
    soft_set install_computer_signals "false"
    soft_set install_git "true"
    soft_set install_ssh "true"
    soft_set install_mesa "false"
    soft_set install_xorg_drivers "false"
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
    soft_set install_java8 "false"
    soft_set install_java11 "false"
    soft_set install_java17 "false"
    soft_set install_javaJDK "true"
    soft_set install_java8JDK "false"
    soft_set install_java11JDK "false"
    soft_set install_java17JDK "false"
    soft_set install_java_management "true"
    soft_set install_openfonts "false"
    soft_set install_openfontsAUR "false"
    soft_set install_libreoffice "false"
    soft_set install_libreofficeAUR "false"
    soft_set install_nativeMS "false"
    soft_set install_MSfonts "false"
    DE="none"
    ;;
  "core")
    SoftSet rootfs "btrfs"
    if [[ "$rootfs" = "btrfs" ]]; then
      soft_set install_snapper "false"
    else
      # if your rootfs isn't btrfs you should never have any of the snapper stuff
      install_snapper="false"
    fi
    soft_set install_security "true"
    soft_set install_optimizations "true"
    soft_set install_computer_signals "false"
    soft_set install_git "true"
    soft_set install_ssh "false"
    soft_set install_mesa "true"
    soft_set install_xorg_drivers "true"
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
    soft_set install_java8 "false"
    soft_set install_java11 "false"
    soft_set install_java17 "false"
    soft_set install_javaJDK "true"
    soft_set install_java8JDK "false"
    soft_set install_java11JDK "false"
    soft_set install_java17JDK "false"
    soft_set install_java_management "false"
    soft_set install_openfonts "true"
    soft_set install_openfontsAUR "true"
    soft_set install_libreoffice "true"
    soft_set install_libreofficeAUR "true"
    soft_set install_nativeMS "false"
    soft_set install_MSfonts "true"
    DE="none"
    ;;
  *) ;;
  esac
}

set_packages() {
  packages=""
  AUR_packages=""
  packages=$general

  for variable in "${variables[@]}"; do
    local install_variable="install_$variable"
    local package_variable="$variable"

    if [[ "${!install_variable}" == "true" ]]; then
      if [[ "${package_variable: -3}" == "AUR" || "$variable" == "MSfonts" || "$variable" == "nativeMS" || "$variable" == "video_3d" || "$variable" == "video_acceleration" || "$variable" == "javaJDK" || "$variable" == "java8JDK" || "$variable" == "java11JDK" || "$variable" == "java17JDK" ]]; then
        AUR_packages+=" ${!package_variable}"
      else
        packages+=" ${!package_variable}"
      fi
    fi
  done

  echlog "Packages: $packages"
  echlog "AUR Packages: $AUR_packages"
}

run() {
  set_template_packages
  set_packages
  powerpill_command "$packages"
  AUR_command $aurpkgs
  install_DE
}

source Configuration.cfg
run
