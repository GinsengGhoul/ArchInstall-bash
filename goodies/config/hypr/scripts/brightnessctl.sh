#!/bin/sh
steps=${2}
current=$(brightnessctl g)
max=$(brightnessctl m)
min="1"
one=$(( $(( ${max} * 1 )) / 100 ))

if [ -z steps ]; then
  echo "use 'up' or 'down' and a step count"
  exit 1
fi

steppercent=$(( 100 / ${steps} ))
stepsize=$( echo "${max} * ${steppercent} / 100" | bc )

case $1 in
  up)
    if [ ${current} -eq 1 ]; then
      newBrightness="${one}"
    else
      if [ ${current} -eq ${one} ]; then
        current=0
      fi
      newBrightness=$(( ${current} + ${stepsize} ))
      if [ ${newBrightness} -gt ${max} ]; then
        newBrightness="${max}"
      fi
    fi
    ;;
  down)
    if [ ${current} -eq ${stepsize} ]; then
      newBrightness="${one}"
    else
      newBrightness=$(( ${current} - ${stepsize} ))
      if [ ${newBrightness} -lt 1 ]; then
        newBrightness="1"
      fi
    fi
    ;;
  *)
    echo "use 'up' or 'down' and a step count"
    exit 1
    ;;
esac

brightnessctl s ${newBrightness}
