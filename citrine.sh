#!/usr/bin/env bash

sudo script -O /var/log/citrine.log -q -c "citrine.internal"
sudo cp /var/log/citrine.log /mnt/var/.
echo "Run 'reboot' to restart. :)"
