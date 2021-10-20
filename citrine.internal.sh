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
    dialog --title Citrine --yesno "$@" 10 80
    yn=$?
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

if [[ "$EUID" != "0" ]]; then
    err "Run as root"
    exit 1
fi

inf "Checking pacman keyrings"
pacman-key --init
pacman-key --populate archlinux
pacman-key --populate crystal

yesno "Do you need a keyboard layout other than QWERTY US?"
KBD="$yn"
echo "KBD=$KBD"

# TODO: layout select in dialog
if [[ "$KBD" == "0" || "$KBD" == "0" ]]; then
    prompt "We're going to show the list of keymaps in less. Do you know how to exit less? (Y/n)"
    UL="$response"
    if [[ "$UL" == "n" ]]; then
        inf "Once we enter less, use arrows to scroll, and q to quit once you've found the right file."
        inf "Press enter to go"
        read
    fi
    localectl list-keymaps
    prompt "Correct keymap"
    KMP="$response"
    echo "KMP=$response"
    loadkeys ${KMP}
fi

clear

yesno "Would you like to partition manually?"
echo "PMODE=$yn"
PMODE="$yn"

dumptitle="System Disks"
diskdat="$(fdisk -l | grep Disk | grep sectors --color=never)"
dump "$diskdat"

MANUAL="no"
DISK=""
if [[ "$PMODE" == "0" ]]; then
    MANUAL="yes"
else
    msgbox "Install target WILL BE FULLY WIPED"
    echo "DISK=$msgdat"
    DISK="$msgdat"
    if ! fdisk -l ${DISK}; then
        dumptitle="ERROR"
        dump "Seems like $DISK doesn't exist. Did you typo?"
        exit 1
    fi
fi

if [[ $DISK == *"nvme"* ]]; then
    inf "Seems like this is an NVME disk. Noting"
    NVME="yes"
else
    NVME="no"
fi
echo "NVME=$NVME"

if [[ -d /sys/firmware/efi/efivars ]]; then
    inf "Seems like this machine was booted with EFI. Noting"
    EFI="yes"
else
    EFI="no"
fi
echo "EFI=$EFI"

dumptitle="Please confirm"
if [[ "$EFI" == "yes" ]]; then
    dump "This PC seems to *have* booted with UEFI. Press enter to confirm, or Control+C to cancel"
else
    dump "This PC seems to *not* have booted with UEFI. Press enter to aknowledge, or press Control+C if this seems wrong."
fi

inf "Setting system clock via network"
timedatectl set-ntp true

if [[ "$MANUAL" == "no" ]]; then

    dumptitle="CAUTION!"
    dump "This is your last chance to avoid deleting critical data on $DISK. If you're not sure, press Control+C NOW!"

    echo "Partitioning disk"
    if [[ "$EFI" == "yes" ]]; then
        parted ${DISK} mklabel gpt --script
        parted ${DISK} mkpart fat32 0 300 --script
        parted ${DISK} mkpart ext4 300 100% --script
        inf "Partitioned ${DISK} as an EFI volume"
    else
        parted ${DISK} mklabel msdos --script
        parted ${DISK} mkpart primary ext4 0% 100% --script
        inf "Partitioned ${DISK} as an MBR volume"
    fi

    if [[ "$NVME" == "yes" ]]; then
        if [[ "$EFI" == "yes" ]]; then
            inf "Initializing ${DISK} as NVME EFI"
            mkfs.vfat ${DISK}p1
            mkfs.ext4 ${DISK}p2
            mount ${DISK}p2 /mnt
            mkdir -p /mnt/efi
            mount ${DISK}p1 /mnt/efi
        else
            inf "Initializing ${DISK} as NVME MBR"
            mkfs.ext4 ${DISK}p1
            mount ${DISK}p1 /mnt
        fi
    else
        if [[ "$EFI" == "yes" ]]; then
            inf "Initializing ${DISK} as EFI"
            mkfs.vfat -F32 ${DISK}1
            mkfs.ext4 ${DISK}2
            mount ${DISK}2 /mnt
            mkdir -p /mnt/efi
            mount ${DISK}1 /mnt/efi
        else
            inf "Initializing ${DISK} as MBR"
            mkfs.ext4 ${DISK}1
            mount ${DISK}1 /mnt
        fi
    fi
else
    clear

    dumptitle="Read carefully!"

    dump "You have chosen manual partitioning.\
    We're going to drop to a shell for you to partition, but first, PLEASE READ these notes.\
    Before you exit the shell, make sure to format and mount a partition for / at /mnt."

    if [[ "$EFI" == "yes" ]]; then
        mkdir -p /mnt/efi

        dump "Additionally, since this machine was booted with UEFI, please make sure to make a 200MB or greater partition\
        of type VFAT and mount it at /mnt/efi"
    else
        msgbox "Please give me the full path of the device you're planning to partition (needed for bootloader installation later)\
        .. Example: /dev/sda"
        DISK="${msgdat}"
    fi

    CONFDONE="NOPE"
    dumptitle="Citrine"

    while [[ "$CONFDONE" == "NOPE" ]]; do
        dump "Press enter to go to a shell. (ZSH)"
        zsh
        yesno "All set (and partitions mounted?)"
        echo "STAT=$yn"
        STAT="$yn"
        if [[ "$STAT" == "0" ]]; then

            if ! findmnt | grep /mnt; then
                err "Are you sure you've mounted the partitions?"
            else
                CONFDONE="YEP"
            fi
        fi
    done
fi

inf "Verifying network connection"
ping -c 1 getcryst.al

if [[ ! "$?" == "0" ]]; then
    dumptitle="Error!"
    dump "It seems like this system can't reach the internet. Failing here."
    umount -l /mnt
    exit 1
fi

inf "Setting up base Crystal System"

crystalstrap /mnt base linux linux-firmware systemd-sysvcompat networkmanager grub crystal-grub-theme man-db man-pages texinfo micro sudo curl archlinux-keyring neofetch dialog
if [[ ! "$?" == "0" ]]; then
    inf "CrystalStrap had some error. Retrying."
    crystalstrap /mnt base linux linux-firmware systemd-sysvcompat networkmanager grub crystal-grub-theme man-db man-pages texinfo micro sudo curl archlinux-keyring neofetch dialog
fi

if [[ "$EFI" == "yes" ]]; then
    inf "Installing EFI support package"
    crystalstrap /mnt efibootmgr
fi

# Grub theme
sed -i 's/\/path\/to\/gfxtheme/\/usr\/share\/grub\/themes\/crystal\/theme.txt/g' /mnt/etc/default/grub
sed -i 's/#GRUB_THEME/GRUB_THEME/g' /mnt/etc/default/grub

cp /usr/bin/continue.sh /mnt/.
chmod +x /mnt/continue.sh

genfstab -U /mnt > /mnt/etc/fstab

if [[ "$KBD" == "y" || "$KBD" == "Y" ]]; then
    echo ${KMP} >> /mnt/keymap
fi

if [[ "$EFI" == "yes" ]]; then
    touch /mnt/efimode
else
    echo ${DISK} > /mnt/diskn
fi


clear

TZ="/usr/share/place/holder"
while [[ ! -f $TZ ]]; do 
    msgbox "Pick a time zone (Format: America/New_York, Europe/London, etc)"
    PT="$response"
    TZ="/usr/share/zoneinfo/${PT}"
done

arch-chroot /mnt ln-sf $TZ /etc/localtime
inf "Set TZ to ${TZ}"
inf "Syncing hardware offset"
arch-chroot /mnt hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

clear
yesno "Do you need more locales than just en_US?"
echo "More=$yn"
More="$yn"

if [[ "$MORE" == "0" ]]; then
    msgbox "Preferred editor"
    PRGRM="$msgdat"
    echo "PGRM=$msgdat"
    if [[ -x "$(command -v ${PGRM})" ]]; then
        inf "Attempting to install ${PGRM}"
        pacman -S ${PGRM} --noconfirm
    fi
    dumptitle="Read carefully."
    dump "When we open the file, please remove the leading # before any locales you need.\
    Then, save and exit."
    ${PGRM} /mnt/etc/locale.gen
fi

inf "Generating selected locales."
arch-chroot /mnt locale-gen

echo
echo
inf "en_US was set as system primary."
inf "After install, you can edit /etc/locale.conf to change the primary if desired."
inf "Press enter"
prompt ""

if [[ -f /mnt/keymap ]];
    inf "You set a custom keymap. We're making that change to the new system, too."
    KMP=$(cat /keymap)
    rm /mnt/keymap
    echo "KEYMAP=${KMP}" > /mnt/etc/vconsole.conf
fi

clear
msgbox "Enter the system hostname"
HOSTNAME="$msgdat"
echo ${HOSTNAME} > /mnt/etc/hostname
echo "127.0.0.1     localhost" > /mnt/etc/hosts

yesno "Would you like IPV6?"
IPS="$yn"

if [[ "$IPS" == "0" ]]; then
    echo "::1       localhost" >> /mnt/etc/hosts
fi
echo "127.0.0.1     ${HOSTNAME}.localdomain ${HOSTNAME}" >> /mnt/etc/hosts

clear
inf "Set a password for root"
done="nope"
while [[ "$done" == "nope" ]]; do
    arch-chroot /mnt passwd
    if [[ "$(echo $?)" == "0" ]]; then
        done="yep"
    fi
done

msgbox "Your username"
UN="$msgdat"
arch-chroot /mnt "useradd -m ${UN} && usermod -aG wheel ${UN}"
inf "Set password for ${UN}"
done="nope"
while [[ "$done" == "nope" ]]; do
    arch-chroot /mnt "passwd ${UN}"
    if [[ "$(echo $?)" == "0" ]]; then
        done="yep"
    fi
done
echo >> /mnt/etc/sudoers
echo "# Enabled by Crystalinstall (citrine)" >> /mnt/etc/sudoers
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers

if [[ -f /mnt/efimode ]]; then
    rm /mnt/efimode
    arch-chroot /mnt "grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Crystal"
else 
    DISK=$(cat /mnt/diskn)
    rm /mnt/diskn
    grub-install ${DISK}
fi

arch-chroot /mnt "grub-mkconfig -o /boot/grub/grub.cfg && systemctl enable NetworkManager && pacman-key --init && pacman-key --populate archlinux && pacman-key --populate crystal"

clear

yesno "Would you like to install a DE/WM profile?"
echo "DEP=$yn"
DEP="$yn"

arch-chroot /mnt "pacman -Sy --quiet --noconfirm"

if [[ "$DEP" == "0" ]]; then
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
    case "$DE" in 
    "Budgie")
        arch-chroot /mnt "pacman -S --quiet --noconfirm budgie-desktop gnome"
        DM="gdm"
        ;;
    "Cinnamon")
        arch-chroot /mnt "pacman -S --quiet --noconfirm cinnamon"
        DM="gdm"
        ;;
    "Deepin")
        arch-chroot /mnt "pacman -S --quiet --noconfirm deepin deepin-extra"
        DM="lightdm"
        ;;
    "Gnome" | "GNOME" | "gnome")
        arch-chroot /mnt "pacman -S --quiet --noconfirm gnome gnome-extra chrome-gnome-shell"
        DM="gdm"
        ;;
    "KDE" | "Kde" | "kde")
        arch-chroot /mnt "pacman -S --quiet --noconfirm plasma kde-applications sddm"
        DM="sddm"
        ;;
    "LXDE" | "lxde" | "Lxde")
        arch-chroot /mnt "pacman -S --quiet --noconfirm lxde"
        DM="lxdm"
        ;;
    "LXQt" | "lxqt" | "Lxqt" | "LXQT")
        arch-chroot /mnt "pacman -S --quiet --noconfirm lxqt breeze-icons xorg"
        DM="sddm"
        ;;
    "Mate" | "mate")
        arch-chroot /mnt "pacman -S --quiet --noconfirm mate mate-extra mate-applet-dock mate-applet-streamer"
        DM="gdm"
        ;;
    "Xfce" | "xfce")
        arch-chroot /mnt "pacman -S --quiet --noconfirm xfce4 xfce4-goodies"
        DM="sddm"
    "Cutefish" |"cutefish")
        arch-chroot /mnt "pacman -S --quiet --noconfirm cutefish"
        DM="sddm"
    "Enlightenment" | "enlightenment")
        arch-chroot /mnt "pacman -S --quiet --noconfirm enlightenment terminology"
        ;;
esac

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
        arch-chroot /mnt "pacman -S --quiet --noconfirm $DM"
            else
        inf "Ok, not installing a display manager."
    fi
else
    arch-chroot /mnt "pacman -S --quiet --noconfirm $DM"
fi
if [[ "$DM" != "" ]]; then
        prompt "Would you like to enable ${DM} for ${DE}? (Y/n)"
        useDM="$response"
        if [[ "$useDM" != "n" ]]; then
            arch-chroot /mnt "systemctl enable ${DM}"
            if [[ "$DE" == "Deepin" ]]; then
                sed -i 's/lightdm-gtk-greeter/lightdm-deepin-greeter/g' /mnt/etc/lightdm/lightdm.conf
            fi
        fi
    fi
fi

prompt "Would you like to add more packages? (Y/n)"
MP="$response"
if [["$MP" != "n" ]]; then
    prompt "Would you like to use a URL to a package list? (Y/n)"
    OL="$response"
    if [["$OL" == "n" ]]; then
        prompt "Write package names"
        PKGNS="$response"
        inf "Installing: $PKGNS"
        arch-chroot /mnt "ame -S ${PKGNS}"
    else 
        prompt "URL to package list"
        SRC="$response"
        PKGS="$(curl ${SRC})"
        for PKG in PKGS; do
            arch-chroot /mnt "ame -S ${PKG}"
        done
    fi
fi

inf "Installation should now be complete."