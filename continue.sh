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

TZ="/usr/share/zoneinfo/FUCK/OFF"

while [[ ! -f $TZ ]]; do
    prompt "Pick a time zone (Format: America/New_York , Europe/London, etc)"
    PT="$response"
    TZ="/usr/share/zoneinfo/${PT}"
done

ln -sf $TZ /etc/localtime
inf "Set TZ to ${TZ}"
inf "Syncing hardware offset"
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

prompt "Do you need more locales than just en_US? (y/N)"
MORE="$response"

if [[ "$MORE" == "y" || "$MORE" == "Y" ]]; then
    prompt "Preferred editor"
    PGRM="$response"
    if [[ -x "$(command -v ${PGRM})" ]]; then
        inf "Attempting to install ${PGRM}"
        pacman -Sy ${PGRM} --noconfirm
    fi
    inf "When we open the file, please remove the leading # before any locales you need."
    inf "Then, save and exit.\nPress enter."
    read
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

prompt "System hostname"
HOSTNAME="$response"
echo ${HOSTNAME} > /etc/hostname
echo "127.0.0.1     localhost" > /etc/hosts
prompt "Would you like IPV6? (y/N)"
IPS="$response"
if [[ "$IPS" == "y" || "$IPS" == "Y" ]]; then
    echo "::1       localhost" >> /etc/hosts
fi
echo "127.0.1.1       ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

inf "Password for root"
passwd

prompt "Your username"
UN="$response"
useradd -m ${UN}
usermod -aG wheel ${UN}
inf "Set password for ${UN}"
passwd ${UN}
echo >> /etc/sudoers
echo "# Enabled by Crystalinstall" >> /etc/sudoers
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

if [[ -f /efimode ]]; then
    rm /efimode
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=CrystalUX
else
    DISK=$(cat /diskn)
    rm /diskn
    grub-install ${DISK}
fi

grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

pacman-key --init
pacman-key --populate archlinux

prompt "Would you like to install a DE profile? (y/N)"
DEP="$response"

if [[ "$DEP" == "y" || "$DEP" == "Y" ]]; then
    inf "- KDE"
    inf "- GNOME"
    inf "- i3"
    inf "(We'll add more as people ask)"
    prompt ""
    DE="$response"

    if [[ "$DE" == "KDE" ]]; then
        pacman -Sy --noconfirm plasma kde-applications sddm
        DM="sddm"
    elif [[ "$DE" == "GNOME" ]]; then
        pacman -Sy --noconfirm gnome gnome-extra
        DM="gdm"
    elif [[ "$DE" == "i3" ]]; then
        inf "Choose either i3 or i3-gaps in below prompt. Rest of group is your preference (or not"
        inf "Press enter"
        prompt ""
        pacman -Sy i3 xorg-xinit xorg-server
        prompt "Would you like a display manager? If so, provide the package name"
        ND="$response"
        if [[ "$ND" != "" ]]; then
            inf "Ok, we'll install $ND"
            DM="$ND"
            pacman -Sy --noconfirm $DM
        else
            inf "Ok, not installing a display manager."
            inf "We're setting up a default .xinitrc for you, though"
            echo "exec i3" > /home/${UN}/.xinitrc
            chown $UN:$UN /home/${UN}/.xinitrc
            chmod +x /home/${UN}/.xinitrc
            DM=""
        fi
    fi

    if [[ "$DM" != "" ]]; then
        prompt "Would you like to enable ${DM} for ${DE}? (Y/n)"
        useDM="$response"
        if [[ "$useDM" != "n" ]]; then
            systemctl enable ${DM}
        fi
    fi
fi

prompt "Would you like to add more packages? (Y/n)"
MP="$response"
if [[ "$MP" != "n" ]]; then
    prompt "Write package names"
    PKGNS="$response"
    pacman -Sy --noconfirm ${PKGNS}
fi

inf "Installation complete"