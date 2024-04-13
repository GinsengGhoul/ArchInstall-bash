#!/bin/sh
cd /RECOVERY
sudo aria2c -s 16 -j8 -x8 -c true -i mirrors.txt
