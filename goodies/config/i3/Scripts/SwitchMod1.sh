#!/bin/bash
i3config="$HOME/.config/i3/config"
i3move="$HOME/.config/i3/config.d/workspace"
sed -i '/^#.*set \$mod Mod1/s/^#//' $i3config

sed -i '/^[^#]*set \$mod Mod4/s/^/#/' $i3config
sed -i 's/^bindsym Control+\$mod+Left exec \$HOME\/.config\/i3\/Scripts\/movetoWorkspace.sh prev/#bindsym Control+\$mod+Left exec \$HOME\/.config\/i3\/Scripts\/movetoWorkspace.sh prev/' $i3move
sed -i 's/^bindsym Control+\$mod+Right exec \$HOME\/.config\/i3\/Scripts\/movetoWorkspace.sh next/#bindsym Control+\$mod+Right exec \$HOME\/.config\/i3\/Scripts\/movetoWorkspace.sh next/' $i3move

i3 reload
