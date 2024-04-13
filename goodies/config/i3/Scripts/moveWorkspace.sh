#!/bin/bash

# Get the current workspace
current_workspace=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused == true).name')
workspace_names=($(i3-msg -t get_workspaces | jq -r '.[] | .name'))

if [ ${#workspace_names[@]} -eq 1 ]; then
  single="true"
else
  single="false"
fi

for workspace in "${workspace_names[@]}"; do
  if [ $workspace -ge 1 ] && [ $workspace -le 4 ]; then
    inRange="true";
  else
    inRange="false";
  fi
done

case $1 in
  next)
    if [[ $single = "true"  || $inRange = "true" ]] && [ $current_workspace -ge 4 ]; then
      target=1
    elif [ $single = "false" ] && [ $inRange = "false" ] && [ $current_workspace = ${workspace_names[-1]} ]; then
      target=${workspace_names[0]}
    else
      target=$(($current_workspace + 1))
    fi
    ;;
  prev)
    if [ $inRange = "true" ] && [ $current_workspace -eq 1 ]; then
      target=4
    elif [ $current_workspace -eq 1 ] && [ $single = "false" ]; then
      target=${workspace_names[-1]}
    else
      target=$(($current_workspace - 1))
    fi
    ;;
  *)
    echo "Invalid direction. Use 'prev' or 'next'."
    exit 1
    ;;
esac

i3-msg "workspace $target"
