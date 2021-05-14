#!/usr/bin/env bash

sudo citrine.internal 0>&1 3>&1 | tee /var/log/citrine.log
sudo cp /var/log/citrine.log /mnt/var/.
echo "Run 'reboot' to restart. :)"