#!/bin/bash

TZ="/usr/share/zoneinfo/FUCK/OFF"

while [[ ! -f $TZ ]]; do
    printf "Pick a time zone (Format: America/New_York , Europe/London, etc): "
    read PT
    TZ="/usr/share/zoneinfo/${PT}"
done

ln -sf $TZ /etc/localtime
echo "Set TZ to ${TZ}"
echo "Syncing hardware offset"
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

printf "Do you need more locales than just en_US? (y/N): "
read MORE

if [[ "$MORE" == "y" || "$MORE" == "Y" ]]; then
    printf "Preferred editor: "
    read PGRM
    if [[ -x "$(command -v ${PGRM})" ]]; then
        echo "Attempting to install ${PGRM}"
        pacman -Sy ${PGRM} --noconfirm
    fi
    echo "When we open the file, please remove the leading # before any locales you need."
    echo "Then, save and exit.\nPress enter."
    read
    ${PGRM} /etc/locale.gen
fi

echo "Generating selected locales."
locale-gen

echo "en_US was set as system primary. After install, you can edit /etc/locale.conf to change the primary if desired."
echo "Press enter"
read

if [[ -f /keymap ]]; then
    echo "You set a custom keymap. We're making that change to the new system, too."
    KMP=$(cat /keymap)
    rm /keymap
    echo "KEYMAP=${KMP}" > /etc/vconsole.conf
fi

printf "System hostname: "
read HOSTNAME
echo ${HOSTNAME} > /etc/hostname
echo "127.0.0.1     localhost" > /etc/hosts
printf "Would you like IPV6? (y/N)"
read IPS
if [[ "$IPS" == "y" || "$IPS" == "Y" ]]; then
    echo "::1       localhost" >> /etc/hosts
fi
echo "127.0.1.1       ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

echo "Password for root"
passwd

printf "Your username: "
read UN
useradd -m ${UN}
usermod -aG wheel ${UN}
echo "Set password for ${UN}"
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
pacman-key --import archlinux

printf "Would you like to install a DE profile? (y/N): "
read DEP

if [[ "$DEP" == "y" || "$DEP" == "Y" ]]; then
    echo "- KDE"
    echo "- GNOME"
    echo "- i3"
    echo "(We'll add more as people ask)"
    printf ": "
    read DE

    if [[ "$DE" == "KDE" ]]; then
        pacman -Sy --noconfirm plasma kde-applications sddm
        DM="sddm"
    elif [[ "$DE" == "GNOME" ]]; then
        pacman -Sy --noconfirm gnome gnome-extra
        DM="gdm"
    elif [[ "$DE" == "i3" ]]; then
        echo "Choose either i3 or i3-gaps in below prompt. Rest of group is your preference (or not"
        echo "Press enter"
        read
        pacman -Sy --noconfirm i3 xorg-xinit xorg-server
        printf "Would you like a display manager? If so, provide the package name: "
        read ND
        if [[ "$ND" != "" ]]; then
            echo "Ok, we'll install $ND"
            DM="$ND"
        else
            echo "Ok, not installing a display manager."
            DM=""
        fi
    fi

    if [[ "$DM" != "" ]]; then
        printf "Would you like to enable ${DM} for ${DE}? (Y/n)"
        read useDM
        if [[ "$useDM" != "n" ]]; then
            systemctl enable ${DM}
        fi
    fi
fi

printf "Would you like to add more packages? (Y/n): "
read MP
if [[ "$MP" != "n" ]]; then
    printf "Write package names: "
    read PKGNS
    pacman -Sy --noconfirm ${PKGNS}
fi

echo "Installation complete"