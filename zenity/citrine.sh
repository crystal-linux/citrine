#!/usr/bin/env bash

sudo script -O /var/log/citrine.log -q -c "citrine.internal.zenity"
sudo cp /var/log/citrine.log /mnt/var/.
sudo echo "!!ZENITY VERSION OF CITRINE USED!!" >> /mnt/var/citrine.log
echo "Run 'reboot' to restart. :)"
