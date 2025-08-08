#!/bin/sh

# Get the current workspace
currentWorkspace=$(hyprctl  -j monitors | jq -r '.[] | select(.activeWorkspace) | .activeWorkspace.id' | tr -d \\n | tr -d ' ')
maxWorkspace=$(hyprctl -j workspaces | jq -r '.[] | .id' | tr '\n' ' ' | sed "s/-[0-9]* //g" | sed "s/-[0-9]*//" | sed "s/ /\n/g" | sort | tail -n 1 | tr -d \\n | tr -d ' ')

if [ ${maxWorkspace} -lt 4 ]; then
  maxWorkspace=4
fi

case $1 in
  next)
    if [ ${currentWorkspace} -eq ${maxWorkspace} ]; then
      target=1
    else
      target=$(( ${currentWorkspace} + 1 ))  # Corrected variable name
    fi
    ;;
  prev)
    if [ ${currentWorkspace} -eq 1 ]; then
      target=${maxWorkspace}
    else
      target=$(( ${currentWorkspace} - 1 ))
    fi
    ;;
  *)
    echo "Invalid direction. Use 'prev' or 'next'."
    exit 1
    ;;
esac

hyprctl dispatch movetoworkspace ${target}
