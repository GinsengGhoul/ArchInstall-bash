#!/bin/sh
current=$(brightnessctl g)
steps=${2}
lastBrightness="${HOME}/.cache/brightness"
max=$(brightnessctl m)
min="1"
one=$(( $(( ${max} * 1 )) / 100 ))

quit(){
  echo "use 'up' or 'down' and a step count"
  echo "or 'restore' to restore to last known brightness value"
  exit 1
}

chechSteps(){
  if [ -z steps ]; then
    quit
  fi
  steppercent=$(( 100 / ${steps} ))
  stepsize=$( echo "${max} * ${steppercent} / 100" | bc )
}

case $1 in
  up)
    chechSteps
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
    chechSteps
    if [ ${current} -eq ${stepsize} ]; then
      newBrightness="${one}"
    else
      newBrightness=$(( ${current} - ${stepsize} ))
      if [ ${newBrightness} -lt 1 ]; then
        newBrightness="1"
      fi
    fi
    ;;
  restore)
    newBrightness=$(cat ${lastBrightness})
    ;;
  *)
    quit
    ;;
esac

brightnessctl s ${newBrightness}
brightnessctl g > ${lastBrightness}
