#!/bin/sh
cd /RECOVERY
sudo aria2c -s 24 -j 12 -x 4 -c true --check-integrity=true -i mirrors.txt
