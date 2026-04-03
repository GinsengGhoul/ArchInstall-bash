#!/bin/sh
internalMontior="eDP-1"
status=$( hyprctl -j monitors all | jq -r ".[] | select(.name == "${internalMontior}") | .disabled" )
echo ${status}
