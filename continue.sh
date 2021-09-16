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

clear
TZ="/usr/share/LMAO/XD"
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
echo "export LANG=\"en_US.UTF-8\"" > /etc/locale.conf
echo "export LC_COLLATE=\"C\"" >> /etc/locale.conf

clear
prompt "Do you need more locales than just en_US? (y/N)"
echo "MORE=$response"
MORE="$response"

if [[ "$MORE" == "y" || "$MORE" == "Y" ]]; then
    prompt "Preferred editor"
    PGRM="$response"
    echo "PGRM=$response"
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

clear
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

INIT=$(cat /initsys)
rm /initsys

if [[ "$INIT" == "openrc" ]]; then
    echo "hostname='${HOSTNAME}'" > /etc/conf.d/hostname
fi

inf "Installing connman"
pacman -S --quiet --noconfirm connman-${INIT} connman-gtk

if [[ "$INIT" == "openrc" ]]; then
    rc-update add connmand default
    rc-update add dbus default
    rc-update add elogind default
elif [[ "$INIT" == "runit" ]]; then
    ln -s /etc/runit/sv/connmand /etc/runit/runsvdir/default
    ln -s /etc/runit/sv/dbus /etc/runit/runsvdir/default
    ln -s /etc/runit/sv/elogind /etc/runit/runsvdir/default
elif [[ "$INIT" == "s6" ]]; then
    s6-rc-bundle-update -c /etc/s6/rc/compiled add default connmand
    s6-rc-bundle-update -c /etc/s6/rc/compiled add default dbus
    s6-rc-bundle-update -c /etc/s6/rc/compiled add default elogind
elif [[ "$INIT" == "66" ]]; then
    66-tree -ncE default
    66-enable -t default connmand
    66-enable -t default dbus
    66-enable -t default elogind
else
    err "No such init: ${INIT}"
    exit 1
fi

clear
inf "Password for root"
done="nope"
while [[ "$done" == "nope" ]]; do
    passwd
    if [[ "$(echo $?)" == "0" ]]; then
        done="yep"
    fi
done

prompt "Your username"
UN="$response"
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
    grub-install --recheck ${DISK}
fi

grub-mkconfig -o /boot/grub/grub.cfg


clear
prompt "Would you like to install a DE/WM profile? (y/N)"
echo "DEP=$response"
DEP="$response"

if [[ "$DEP" == "y" || "$DEP" == "Y" ]]; then
    inf "--- Desktop Environments ---"
    inf "- Budgie"
    inf "- Cinnamon"
    inf "- Deepin"
    inf "- Enlightenment (note: very DIY. Read Arch Wiki)"
    inf "- GNOME"
    # Flashback seems to need some work
    #inf "- (GNOME) Flashback"
    inf "- KDE"
    inf "- LXDE"
    inf "- LXQt"
    inf "- Mate"
    inf "- Cutefish"
    inf "- Xfce"
    inf "- UKUI (note: very poorly documented. In english, anyway)"
    inf "--- Window Managers ---"
    inf "- i3"
    inf "(We'll add more as people ask)"
    inf "Please enter exactly as shown."
    prompt ""
    echo "DE=$response"
    DE="$response"
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
    elif [[ "$DE" == "Enlightenment" ]]; then
        pacman -Sy --quiet --noconfirm enlightenment terminology
    elif [[ "$DE" == "GNOME" ]]; then
        pacman -Sy --quiet --noconfirm gnome gnome-extra #chrome-gnome-shell
        DM="gdm"
    elif [[ "$DE" == "Flashback" || "$DE" == "GNOME Flashback" || "$DE" == "(GNOME) Flashback" ]]; then
        DE="Flashback"
        pacman -Sy --quiet --noconfirm gnome-flashback gnome-backgrounds gnome-control-center network-manger-applet gnome-applets sensors-applet
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
    elif [[ "$DE" == "UKUI" ]]; then
        pacman -Sy --quiet --noconfirm ukui
    elif [[ "$DE" == "Xfce" ]]; then
        pacman -Sy --quiet --noconfirm xfce4 xfce4-goodies
        DM="sddm"
    elif [[ "$DE" == "Cutefish" || "$DE" == "cutefish" ]] ;then
        pacman -Sy --quiet --noconfirm cutefish
        DM="sddm"
    # Start WM's
    elif [[ "$DE" == "i3" ]]; then
        inf "Choose either i3 or i3-gaps in below prompt. Rest of group is your preference"
        inf "Press enter"
        prompt ""
        pacman -Sy i3 xorg-xinit xorg-server
    fi

    if [[ "$DM" == "" ]]; then
        inf "Your selected DE/WM doesn't have a standard display manager. Enter one of the below names, or leave blank for none"
        inf "- gdm"
        inf "- sddm"
        inf "- lightdm (you'll need a greeter package. See Arch Wiki)"
        inf "- (you can type another Arch package name if you have one in mind)"
        inf "- [blank] for none"
        prompt ""
        ND="$response"
        echo "ND=$ND"
        if [[ "$ND" != "" ]]; then
            inf "Ok, we'll install $ND"
            DM="$ND"
            pacman -Sy --quiet --noconfirm $DM-${INIT}
        else
            inf "Ok, not installing a display manager."
        fi
    else
        pacman -Sy --quiet --noconfirm $DM-${INIT}
    fi

    if [[ "$DM" != "" ]]; then
        prompt "Would you like to enable ${DM} for ${DE}? (Y/n)"
        useDM="$response"
        if [[ "$useDM" != "n" ]]; then
            if [[ "$INIT" == "openrc" ]]; then
                rc-update add $DM
            elif [[ "$INIT" == "runit" ]]; then
                ln -s /etc/runit/sv/$DM /etc/runit/runsvdir/default
            elif [[ "$INIT" == "s6" ]]; then
                s6-rc-bundle-update -c /etc/s6/rc/compiled add default $DM
            elif [[ "$INIT" == "66" ]]; then
                66-enable -t default $DM
            fi
            if [[ "$DE" == "Deepin" ]]; then
                sed -i 's/lightdm-gtk-greeter/lightdm-deepin-greeter/g' /etc/lightdm/lightdm.conf
            fi
        fi
    fi
fi

prompt "Would you like to add more packages? (Y/n)"
MP="$response"
if [[ "$MP" != "n" ]]; then
    prompt "Would you like to use a URL to a package list? (Y/n)"
    OL="$response"
    if [[ "$OL" == "n" ]]; then
        prompt "Write package names"
        PKGNS="$response"
        inf "Installing: $PKGNS"
        pacman -S --noconfirm --quiet ${PKGNS}
    else
        prompt "URL to package list"
        SRC="$response"
        PKGS="$(curl ${SRC})"
        for PKG in PKGS; do
            pacman -S --quiet --noconfirm ${PKG}
        done
    fi
fi

inf "Installation complete"

if [[ "$INIT" == "66" ]]; then
    err "Make sure to read https://wiki.artixlinux.org/Main/Installation at the very bottom for 66-specific post-install"
fi
