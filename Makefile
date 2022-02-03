install:
	pacman -Sy dialog --noconfirm --needed
    chmod +x *.sh
    cp *.sh /usr/bin
    mv /usr/bin/citrine.sh /usr/bin/citrine
    mv /usr/bin/citrine.internal.sh /usr/bin/citrine.internal
test: install
	citrine