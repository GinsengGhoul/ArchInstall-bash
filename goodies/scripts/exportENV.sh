#!/bin/sh

# Check if a filename argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

# Define a pattern to exclude common desktop environment variables
EXCLUDE_PATTERN='^DISPLAY=|^GDMSESSION|^TERM|^XDG_|^GTK_|^GTK3_|^QT_|^GNOME_|^KDE_|^SESSION_|^DBUS_|^WAYLAND_|^GDM_|^XAUTHORITY|^MAIL|^USER|^MATE_|^I3|^LANG|^WINIT_X11_SCALE_FACTOR|^SHLVL|^SHELL|^HOME|^MOTD_SHOWN|^PWD|^OLDPWD|^TERMINFO|^DESKTOP_SESSION|^DESKTOP_STARTUP_ID|^DESKTOP_AUTOSTART_ID|^KITTY_|^ALACRITTY_|^WINDOWID|^P9K_|^_P9K|^COLORTERM|^DEBUGINFOD|^LOGNAME|^_=|^CMAKE_|^USE_CCACHE|^CCACHE_EXEC'

# Export the current environment variables to the specified file, excluding the patterns
#printenv | grep -vE "$EXCLUDE_PATTERN" | sed 's/^/export /' > "$1"
printenv | grep -vE "$EXCLUDE_PATTERN" | sed 's/^/export "/; s/$/"/' > "$1"

echo "Environment variables exported to "$1"."

cat "$1"

