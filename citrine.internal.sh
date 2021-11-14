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
        parted ${DISK} mkpart primary btrfs 512MIB 100% --script
        parted ${DISK} mkpart primary ext4 1MIB 512MIB --script
        inf "Partitioned ${DISK} as an MBR volume"
    fi

    if [[ "$NVME" == "yes" ]]; then
        if [[ "$EFI" == "yes" ]]; then
            inf "Initializing ${DISK} as NVME EFI"
            mkfs.vfat ${DISK}p1
            mkfs.btrfs -f ${DISK}p2
            mount ${DISK}p2 /mnt
            cd /mnt
            btrfs subvolume create @
            btrfs subvolume create @home
            cd /
            umount /mnt
            mount -o subvol=@ /dev/${DISK}p2 /mnt
            mkdir -p /mnt/{boot/efi,home}
            mount -o subvol=@home /dev/${DISK}p2 /mnt/home
            mount ${DISK}p1 /mnt/boot/efi
        else
            inf "Initializing ${DISK} as NVME MBR"
            mkfs.btrfs -f ${DISK}p1
            mount ${DISK}1 /mnt
            cd /mnt
            btrfs subvolume create @
            btrfs subvolume create @home 
            cd /
            umount /mnt
            mount -o noatime,subvol=@ ${DISK}p1 /mnt
            mkdir -p /mnt/{home,boot}
            mount -o noatime,subvol=@home ${DISK}p1 /mnt/home
            mount ${DISK}p2 /mnt/boot
        fi
    else
        if [[ "$EFI" == "yes" ]]; then
            inf "Initializing ${DISK} as EFI"
            mkfs.vfat -F32 ${DISK}1
            mkfs.btrfs -f ${DISK}2
            mount ${DISK}2 /mnt
            cd /mnt
            btrfs subvolume create @
            btrfs subvolume create @home
            cd /
            umount /mnt
            mount -o subvol=@ /dev/${DISK}2 /mnt
            mkdir -p /mnt/{boot/efi,home}
            mount -o subvol=@home /dev/${DISK}2 /mnt/home
            mount ${DISK}1 /mnt/boot/efi
        else
            inf "Initializing ${DISK} as MBR"
            mkfs.btrfs -f ${DISK}1
            mount ${DISK}1 /mnt
            cd /mnt
            btrfs subvolume create @
            btrfs subvolume create @home 
            cd /
            umount /mnt
            mount -o noatime,subvol=@ ${DISK}1 /mnt
            mkdir -p /mnt/{home,boot}
            mount -o noatime,subvol=@home ${DISK}1 /mnt/home
            mount ${DISK}2 /mnt/boot
        fi
    fi
else
    clear

    dumptitle="Read carefully!"

    dump "You have chosen manual partitioning.\
    We're going to drop to a shell for you to partition, but first, PLEASE READ these notes.\
    Before you exit the shell, make sure to format and mount a partition for / at /mnt."

    if [[ "$EFI" == "yes" ]]; then
        mkdir -p /mnt/boot/efi

        dump "Additionally, since this machine was booted with UEFI, please make sure to make a 200MB or greater partition\
        of type VFAT and mount it at /mnt/boot/efi"
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

crystalstrap /mnt base linux linux-firmware systemd-sysvcompat networkmanager man-db man-pages texinfo micro sudo curl archlinux-keyring neofetch btrfs-progs timeshift timeshift-autosnap
if [[ ! "$?" == "0" ]]; then
    inf "CrystalStrap had some error. Retrying."
    crystalstrap /mnt base linux linux-firmware systemd-sysvcompat networkmanager man-db man-pages texinfo micro sudo curl archlinux-keyring neofetch btrfs-progs timeshift timeshift-autosnap
fi

if [[ "$EFI" == "yes" ]]; then
    inf "Installing EFI support package"
    crystalstrap /mnt efibootmgr refind
else 
    inf "Installing Syslinux bootloader"
    crystalstrap /mnt syslinux
fi

genfstab -U /mnt > /mnt/etc/fstab

clear

TZ="/usr/share/place/holder"
while [[ ! -f $TZ ]]; do 
    msgbox "Pick a time zone (Format: America/New_York, Europe/London, etc)"
    PT="$msgdat"
    TZ="/usr/share/zoneinfo/${PT}"
done


#cd /usr/share/zoneinfo/
#var=$(echo */ | sed 's/\///g' | sed 's/ /" "" "/g')
#var=$(echo \"$var\")
#loc1=$(dialog --title "Citrine" --menu "Please pick a time zone" 20 100 43 $var "" --stdout)
#loc1=$(echo $loc1 | sed 's/"//g')
#cd /usr/share/zoneinfo/$loc1
#var1=$(echo * | sed 's/\///g' | sed 's/ /" "" "/g')
#var1=$(echo \"$var1\")
#loc2=$(dialog --title "Citrine" --menu "Please pick a time zone" 20 100 43 $var1 "" --stdout)
#loc2=$(echo $loc1 | sed 's/"//g')
#TZ="/usr/share/zoneinfo/$loc1/$loc2"
#cd /

arch-chroot /mnt ln -sf $TZ /etc/localtime
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

if [[ "$KBD" == "y" || "$KBD" == "Y" ]]; then
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
arch-chroot /mnt useradd -m ${UN}
arch-chroot /mnt usermod -aG wheel ${UN}
inf "Set password for ${UN}"
done="nope"
while [[ "$done" == "nope" ]]; do
    arch-chroot /mnt passwd ${UN}
    if [[ "$(echo $?)" == "0" ]]; then
        done="yep"
    fi
done
echo >> /mnt/etc/sudoers
echo "# Enabled by Crystalinstall (citrine)" >> /mnt/etc/sudoers
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers

if [[ "$EFI" == "yes" ]]; then
    root="$(findmnt -n -o SOURCE /mnt/ | awk 'BEGIN { FS = "/" }; { print $3 }')"
    arch-chroot /mnt refind-install
    echo '"Crystal Linux"          "rw root=/dev/placeholder"' > /mnt/boot/refind_linux.conf
    sed -i "s/placeholder/$root/" /mnt/boot/refind_linux.conf
else 
    arch-chroot /mnt curl https://git.getcryst.al/crystal/Syslinux_install_script/raw/branch/master/syslinux-install_update -o /usr/bin/syslinux-install_update
    arch-chroot /mnt syslinux-install_update -i -a -m
fi

arch-chroot /mnt systemctl enable NetworkManager
arch-chroot pacman-key --init
arch-chroot pacman-key --populate archlinux
arch-chroot pacman-key --populate crystal

clear

#yesno "Would you like to install a DE/WM profile?"
#echo "DEP=$yn"
#DEP="$yn"

arch-chroot /mnt pacman -Sy --quiet --noconfirm

while [[ "$DE" == "" ]]; do
    menu=$(dialog --title "Citrine" --menu "Select the Desktop Environment you want to install" 12 100 4 "Official" "Our pre-themed desktop environments" "Third Party (supported)" "Third party Desktop Environments that are supported" "Third Party (unsupported)" "Third Party Desktop Environments that aren't supported" "None/DIY" "Install no de from this list" --stdout)
    if [[ "$menu" == "Official" ]]; then
        DE=$(dialog --title "Citrine" --menu "Please choose the DE you want to install" 12 100 2 "Onyx" "Our custom Desktop Environment based on XFCE" "Onyx tiling" "Our custom Desktop Environment based on xfce but with i3 as the wm" --stdout)
    elif [[ "$menu" == "Third Party (supported)" ]]; then
        DE=$(dialog --title "Citrine" --menu "Please choose the DE you want to install" 12 100 5 "Gnome" "The Gnome desktop environment" "KDE" "The KDE desktop environment" "Xfce" "The xfce desktop environment" "budgie" "The budgie desktop environment" "Mate" "The Mate desktop environment" --stdout)
    elif [[ "$menu" == "Third Party (unsupported)" ]]; then
        DE=$(dialog --title "Citrine" --menu "Please choose the DE you want to install" 12 100 2 "Pantheon" "The Pantheon desktop environment from elementaryos" "Enlightenment" "A very DIY desktop environment, refer to archwiki" --stdout)
    elif [[ "$menu" == "None/DIY" ]]; then
        yesno "Are you sure that you dont want to install any DE?"
        if [[ "$yn" == "0" ]]; then
            DE="none"
            DM="none"
        else
            DE=""
        fi
    fi
done
if [[ "$DE" == "Onyx" ]]; then
    #arch-chroot /mnt pacman -S --quiet --noconfirm onyx
    #DM="lightdm"
    dumptitle="Desktop Environment"
    dump "Onyx is not supported yet, please choose another DE"
    DE=""
elif [[ "$DE" == "Onyx tiling" ]]; then
    #arch-chroot /mnt pacman -S --quiet --noconfirm onyx-tiling
    #DM="lightdm"
    dumptitle="Desktop Environment"
    dump "Onyx is not supported yet, please choose another DE"
    DE=""
elif [[ "$DE" == "Gnome" ]]; then
    arch-chroot /mnt pacman -S --quiet --noconfirm gnome gnome-extra chrome-gnome-shell
    DM="gdm"
elif [[ "$DE" == "KDE" ]]; then
    arch-chroot /mnt pacman -S --quiet --noconfirm plasma kde-applications sddm
    DM="sddm"
elif [[ "$DE" == "budgie" ]]; then
    arch-chroot /mnt pacman -S --quiet --noconfirm budgie-desktop gnome
    DM="gdm"
elif [[ "$DE" == "Mate" ]]; then
    arch-chroot /mnt pacman -S --quiet --noconfirm mate mate-extra mate-applet-dock mate-applet-streamer
    DM="gdm"
elif [[ "$DE" == "Pantheon" ]]; then
    arch-chroot /mnt su - ${UN} -c "ame -S gala wingpanel pantheon-applications-menu plank pantheon-geoclue2-agent pantheon-polkit-agent pantheon-print pantheon-settings-daemon lightdm lightdm-pantheon-greeter pantheon-default-settings elementary-icon-theme elementary-wallpapers gtk-theme-elementary ttf-droid ttf-opensans ttf-roboto sound-theme-elementary capnet-assist epiphany pantheon-calculator pantheon-calendar pantheon-camera pantheon-code pantheon-files pantheon-mail pantheon-music pantheon-photos pantheon-screencast pantheon-shortcut-overlay pantheon-terminal pantheon-videos simple-scan pantheon-session pantheon switchboard-plugin-desktop" > /mnt/pantheon-packages.txt
    DM="lightdm"
elif [[ "$DE" == "Enlightenment" ]]; then
    arch-chroot /mnt pacman -S --quiet --noconfirm enlightenment terminology
elif [[ "$DE" == "Xfce" ]]; then
    arch-chroot /mnt pacman -S --quiet --noconfirm xfce4 xfce4-goodies
    DM="lightdm"
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
        arch-chroot /mnt pacman -S --quiet --noconfirm $DM
            else
        inf "Ok, not installing a display manager."
    fi
else
    if [[ "$DM" == "none" ]]; then
        arch-chroot /mnt pacman -S --quiet --noconfirm $DM
    fi
fi
if [[ "$DM" != "" ]]; then
    if [[ "$DM" != "none" ]]; then
        prompt "Would you like to enable ${DM} for ${DE}? (Y/n)"
        useDM="$response"
        if [[ "$useDM" != "n" ]]; then
            arch-chroot /mnt systemctl enable ${DM}
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
        arch-chroot /mnt su - ${UN} -c "ame -S ${PKGNS}"
    else 
        prompt "URL to package list"
        SRC="$response"
        PKGS="$(curl ${SRC})"
        for PKG in PKGS; do
            arch-chroot /mnt su - ${UN} -c "ame -S ${PKG}"
        done
    fi
fi

inf "setting up timeshift"
arch-chroot /mnt timeshift --btrfs

inf "Installation should now be complete."
