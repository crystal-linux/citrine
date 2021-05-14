#!/usr/bin/env bash

sudo citrine.internal 2>&1 | sudo tee /var/log/citrine.log
sudo cp /var/log/citrine.log /mnt/var/.
echo "Run 'reboot' to restart. :)"