#!/bin/sh
# add windows version closest to what would be insalled when sold to kernel line
# eg. acpi_osi=! acpi_osi='Windows 2013'
mkdir -p /tmp/acpi
cd /tmp/acpi
sudo acpidump -b
for i in *; do
  #echo $i:
  strings -a $i | grep -i windows;
done
sudo rm -r /tmp/acpi
