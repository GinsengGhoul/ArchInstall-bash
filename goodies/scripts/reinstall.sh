#!/bin/sh
# change and make sure pacman repo heirarchy is correct before running this script
exclude=("VTI" "JTI" "xxd-standalone-git")
raw_package_list=$(sudo pacman -Qq)

for pkg in "${exclude[@]}"
do
  raw_package_list="$(echo "$raw_package_list" | grep -v "$pkg")"  
done

package_list=($(echo "$raw_package_list" | grep -vx "$( sudo pacman -Qmq )"))
exp_list=($(echo "$raw_package_list" | grep "$( sudo pacman -Qtq )"))

packages=${package_list[0]}
pacmanpackages=${package_list[0]}
exp=${exp_list[0]}
for ((i = 1; i < ${#package_list[@]}; i++))
do
  pacmanpackages+=" --overwrite "${package_list[i]}""
  packages+=" "${package_list[i]}""
  exp+=" "${exp_list[i]}""
done

echo $packages > /tmp/reinstall-packages
echo $exp > /tmp/explicit-packages
#sudo sh -c "pacman -Syy && powerpill -S --noconfirm $pacmanpackages && pacman -D --asdeps $deps && pacman -D --asdep $packages && pacman -D --asexplicit $exp"
sudo pacman -D --asdep $packages && sudo pacman -D --asexplicit $exp
