#!/bin/sh

cd /RECOVERY
sudo wget -N "https://geo.mirror.pkgbuild.com/iso/latest/sha256sums.txt"
#sudo wget -N "https://geo.mirror.pkgbuild.com/iso/latest/b2sums.txt"
#sudo wget -N "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso.sig"

# Function to check the checksum
check_checksum() {
  EXPECTED_SHA256=$(grep "archlinux-x86_64.iso" sha256sums.txt | awk '{print $1}')
  SHA256_CHECKSUM=$(sha256sum archlinux-x86_64.iso | awk '{print $1}')

  if [ "$SHA256_CHECKSUM" != "$EXPECTED_SHA256" ]; then
    printf "NONMATCHING SHA256SUMS\nExpected: $EXPECTED_SHA256\nActual: $SHA256_CHECKSUM\n"
    return 1  # Return 1 for mismatch
  else
    printf "SHA256SUM MATCHED\nExpected:\t$EXPECTED_SHA256\nActual:\t\t$SHA256_CHECKSUM\n"
    return 0  # Return 0 for match
  fi
}

# Initial checksum check
check_checksum
CHECKSUM_RESULT=$?

if [ $CHECKSUM_RESULT -ne 0 ]; then
  # If checksum does not match, download the ISO
  sudo aria2c -s 16 -j8 -x8 -c true -i mirrors.txt
  # Check the checksum again after downloading
  check_checksum
  CHECKSUM_RESULT=$?
fi

# Exit with the checksum result
exit $CHECKSUM_RESULT

