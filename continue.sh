#!/bin/bash

inf() {
    echo -e "\e[1m♠ $@\e[0m"
}

err() {
    echo -e "\e[1m\e[31m✗ $@\e[0m"
}

response=""
prompt() {
    printf "\e[1m\e[33m$@ : \e[0m"
    read response
}

# ---------------------------------
yn=""
yesno() {
    yn=$(dialog --title Citrine --yesno "$@" --stdout 10 80)
}

dumptitle=""
dump() {
    dialog --title "${dumptitle}" --no-collapse --msgbox "$@" 0 0
}

msgdat=""
msgbox(){
    msgdat=$(dialog --title Citrine --inputbox "$@" --stdout 10 80)
}
# --------------------------

clear
TZ="/usr/share/LMAO/XD"
while [[ ! -f $TZ ]]; do
    msgbox "Pick a time zone (Format: America/New_York , Europe/London, etc)"
    PT="$response"
    TZ="/usr/share/zoneinfo/${PT}"
done

ln -sf $TZ /etc/localtime
inf "Set TZ to ${TZ}"
inf "Syncing hardware offset"
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

clear
yesno "Do you need more locales than just en_US?"
echo "MORE=$yn"
MORE="$yn"

if [[ "$MORE" == "0" ]]; then
    msgbox "Preferred editor"
    PGRM="$msgdat"
    echo "PGRM=$msgdat"
    if [[ -x "$(command -v ${PGRM})" ]]; then
        inf "Attempting to install ${PGRM}"
        pacman -Sy ${PGRM} --noconfirm
    fi
    dumptitle="Read carefully."
    dump "When we open the file, please remove the leading # before any locales you need.\
    Then, save and exit."
    ${PGRM} /etc/locale.gen
fi

inf "Generating selected locales."
locale-gen

echo
echo
inf "en_US was set as system primary."
inf "After install, you can edit /etc/locale.conf to change the primary if desired."
inf "Press enter"
prompt ""

if [[ -f /keymap ]]; then
    inf "You set a custom keymap. We're making that change to the new system, too."
    KMP=$(cat /keymap)
    rm /keymap
    echo "KEYMAP=${KMP}" > /etc/vconsole.conf
fi

clear
msgbox "Enter the system hostname"
HOSTNAME="$msgdat"
echo ${HOSTNAME} > /etc/hostname
echo "127.0.0.1     localhost" > /etc/hosts

yesno "Would you like IPV6?"
IPS="$yn"

if [[ "$IPS" == "0" ]]; then
    echo "::1       localhost" >> /etc/hosts
fi
echo "127.0.1.1       ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

clear
inf "Set a password for root"
done="nope"
while [[ "$done" == "nope" ]]; do
    passwd
    if [[ "$(echo $?)" == "0" ]]; then
        done="yep"
    fi
done

msgbox "Your username"
UN="$msgdat"
useradd -m ${UN}
usermod -aG wheel ${UN}
inf "Set password for ${UN}"
done="nope"
while [[ "$done" == "nope" ]]; do
    passwd ${UN}
    if [[ "$(echo $?)" == "0" ]]; then
        done="yep"
    fi
done

echo >> /etc/sudoers
echo "# Enabled by Crystalinstall" >> /etc/sudoers
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

if [[ -f /efimode ]]; then
    rm /efimode
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Crystal
else
    DISK=$(cat /diskn)
    rm /diskn
    grub-install ${DISK}
fi

grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

pacman-key --init
pacman-key --populate archlinux
pacman-key --populate crystal


clear

yesno "Would you like to install a DE/WM profile?"

echo "DEP=$yn"
DEP="$yn"

if [[ "$DEP" == "0" ]]; then

    dumptitle="Desktop/WM Choices"

    dump "\
    --- Desktop Environments ---
    - Budgie
    - Cinnamon
    - Deepin
    - GNOME
    - KDE
    - LXDE
    - LXQt
    - Mate
    - Xfce"

    msgbox "DE Choice (please enter exactly)"
    echo "DE=$msgdat"
    DE="$msgdat"
    DM=""

    if [[ "$DE" == "Budgie" ]]; then
        pacman -Sy --quiet --noconfirm budgie-desktop gnome
        DM="gdm"
    elif [[ "$DE" == "Cinnamon" ]]; then
        pacman -Sy --quiet --noconfirm cinnamon
        DM="gdm"
    elif [[ "$DE" == "Deepin" ]]; then
        pacman -Sy --quiet --noconfirm deepin deepin-extra
        DM="lightdm"
    elif [[ "$DE" == "GNOME" ]]; then
        pacman -Sy --quiet --noconfirm gnome gnome-extra chrome-gnome-shell
        DM="gdm"
    elif [[ "$DE" == "KDE" ]]; then
        pacman -Sy --quiet --noconfirm plasma kde-applications sddm
        DM="sddm"
    elif [[ "$DE" == "LXDE" ]]; then
        pacman -Sy --quiet --noconfirm lxde
        DM="lxdm"
    elif [[ "$DE" == "LXQt" ]]; then
        pacman -Sy --quiet --noconfirm lxqt breeze-icons xorg 
        DM="sddm"
    elif [[ "$DE" == "Mate" ]]; then
        pacman -Sy --quiet --noconfirm mate mate-extra mate-applet-dock mate-applet-streamer
        DM="gdm"
    elif [[ "$DE" == "Xfce" ]]; then
        pacman -Sy --quiet --noconfirm xfce4 xfce4-goodies
        DM="sddm"
    elif [[ "$DE" == "Cutefish" || "$DE" == "cutefish" ]] ;then
        pacman -Sy --quiet --noconfirm cutefish
        DM="sddm"

    if [[ "$DM" != "" ]]; then
        yesno "Would you like to enable ${DM} for ${DE}?"
        useDM="$yn"
        if [[ "$useDM" == "0" ]]; then
            systemctl enable ${DM}
            if [[ "$DE" == "Deepin" ]]; then
                sed -i 's/lightdm-gtk-greeter/lightdm-deepin-greeter/g' /etc/lightdm/lightdm.conf
            fi
        fi
    fi
fi

yesno "Would you like to add more packages?"
MP="$yn"
if [[ "$MP" == "0" ]]; then
    yesno "Would you like to use a URL to a package list?"
    OL="$yesno"
    if [[ "$OL" != "0" ]]; then
        msgbox "Package names"
        PKGNS="$msgdat"
        inf "Installing: $PKGNS"
        ame -S ${PKGNS}
    else
        msgbox "URL to package list"
        SRC="$msgdat"
        PKGS="$(curl ${SRC})"
        for PKG in PKGS; do
            ame -S ${PKG}
        done
    fi
fi

#inf "Installation complete"
