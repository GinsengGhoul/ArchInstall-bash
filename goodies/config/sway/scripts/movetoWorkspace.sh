#!/bin/sh

# Get the current workspace
activeWorkspace=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused == true).name')
maxWorkspace=$(swaymsg -t get_workspaces | jq -r '.[] | .name' | tail -n 1)

if [ ${maxWorkspace} -lt 4 ]; then
  maxWorkspace="4"
fi

case $1 in
  next)
    if [ ${activeWorkspace} -eq ${maxWorkspace} ]; then
      target="1"
    else
      target=$(( ${activeWorkspace} + 1 ))
    fi
    ;;
  prev)
    if [ ${activeWorkspace} -eq 1 ]; then
      target=${maxWorkspace}
    else
      target=$(( ${activeWorkspace} - 1 ))
    fi
    ;;
  *)
    echo "Invalid direction. Use 'prev' or 'next'."
    ;;
esac

swaymsg "move to workspace $target"
swaymsg "workspace $target"
