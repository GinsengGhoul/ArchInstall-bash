#!/bin/sh
cd /RECOVERY
sudo wget -N "https://geo.mirror.pkgbuild.com/iso/latest/sha256sums.txt"
sudo aria2c -s 16 -j8 -x8 -c true -i mirrors.txt

EXPECTED_SHA256=$(grep "archlinux-x86_64.iso" sha256sums.txt | awk '{print $1}')
SHA256_CHECKSUM=$(sha256sum archlinux-x86_64.iso | awk '{print $1}')

if [ "$SHA256_CHECKSUM" != "$EXPECTED_SHA256" ]; then
  printf "NONMATCHING SHA256SUMS\n"$EXPECTED_SHA256"\n"$SHA256_CHECKSUM"\n"
fi
