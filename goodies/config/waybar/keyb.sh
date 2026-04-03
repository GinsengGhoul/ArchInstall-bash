#!/bin/sh
if ! pidof wvkbd-deskintl > /dev/null; then
  wvkbd-deskintl &
else
  kill -34 $(pidof wvkbd-deskintl)
fi
