#!/bin/sh
cd /RECOVERY
sudo aria2c -s 24 -j 12 -x 4 -c true -i mirrors.txt
