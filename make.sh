#!/bin/bash

ins() {
    pacman -Sy dialog --noconfirm --needed
    chmod +x *.sh
    cp *.sh /usr/bin
    mv /usr/bin/citrine.sh /usr/bin/citrine
    mv /usr/bin/citrine.internal.sh /usr/bin/citrine.internal
}

testc() {
    citrine
}

insZen() {
    pacman -Sy zenity --noconfirm --needed
    chmod +x zenity/*.sh
    cp zenity/*.sh /usr/bin
    mv /usr/bin/citrine.sh /usr/bin/citrine
    mv /usr/bin/citrine.internal.zenity.sh /usr/bin/citrine.internal.zenity
}

if [[ "$1" == "" ]]; then
    echo "./make.sh install - installs citrine"
    echo "./make.sh test - (installs) then runs citrine"
    exit 1
fi

if [[ "$1" == "install" ]]; then
    ins
elif [[ "$1" == "install-zenity" ]]; then
    insZen
elif [[ "$1" == "test-zenity" ]]; then
    insZen
    testc
elif [[ "$1" == "test" ]]; then
    ins
    testc
fi