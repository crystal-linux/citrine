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

if [[ "$EUID" != "0" ]]; then
    err "Run as root"
    exit 1
fi

inf "Checking pacman keyrings"
pacman-key --init
pacman-key --populate archlinux
pacman-key --populate crystal

prompt "Do you need a keyboard layout other than standard US? (y/N)"
KBD="$response"
echo "KBD=$response"
if [[ "$KBD" == "y" || "$KBD" == "Y" ]]; then
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

inf "Disks:"
fdisk -l | grep Disk | grep sectors --color=never

prompt "Would you like to partition manually? (y/N)"
echo "PMODE=$response"
PMODE="$response"

MANUAL="no"
DISK=""
if [[ "$PMODE" == "y" ]]; then
    MANUAL="yes"
else
    prompt "Install target WILL BE FULLY WIPED"
    echo "DISK=$response"
    DISK="$response"
    if ! fdisk -l ${DISK}; then
        err "Seems like $DISK doesn't exist. Did you typo?"
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

inf "Setting system clock via network"
timedatectl set-ntp true

if [[ "$MANUAL" == "no" ]]; then
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
            mkfs.vfat ${DISK}1
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
    inf "You have chosen manual partitioning."
    inf "We're going to drop to a shell for you to partition, but first, PLEASE READ these notes."
    inf "Before you exit the shell, make sure to format and mount a partition for / at /mnt"
    if [[ "$EFI" == "yes" ]]; then
        mkdir -p /mnt/efi
        inf "Additionally, since this machine was booted with UEFI, please make sure to make a 200MB or greater partition"
        inf "of type VFAT and mount it at /mnt/efi"
    else
        inf "Please give me the full path of the device you're planning to partition (needed for bootloader installation later)"
        inf "Example: /dev/sda"
        printf ": "
        read DISK
    fi

    CONFDONE="NOPE"

    while [[ "$CONFDONE" == "NOPE" ]]; do
        inf "Press enter to go to a shell."
        read
        bash
        prompt "All set (and partitions mounted?) (y/N)"
        echo "STAT=$response"
        STAT="$response"
        if [[ "$STAT" == "y" ]]; then

            if ! findmnt | grep /mnt; then
                err "Are you sure you've mounted the partitions?"
            else
                CONFDONE="YEP"
            fi
        fi
    done
fi

inf "Setting up base Crystal System"
crystalstrap /mnt base linux linux-firmware systemd-sysvcompat networkmanager grub crystal-grub-theme man-db man-pages texinfo nano sudo curl archlinux-keyring neofetch
if [[ "$EFI" == "yes" ]]; then
    inf "Installing EFI support package"
    crystalstrap /mnt efibootmgr
fi

# Grub theme
sed -i 's/\/path\/to\/gfxtheme/\/usr\/share\/grub\/themes\/crystal\/theme.txt/g' /mnt/etc/default/grub
sed -i 's/#GRUB_THEME/GRUB_THEME/g' /mnt/etc/default/grub

cp /usr/bin/continue.sh /mnt/.
chmod +x /mnt/continue.sh

genfstab -U /mnt >> /mnt/etc/fstab

if [[ "$KBD" == "y" || "$KBD" == "Y" ]]; then
    echo ${KMP} >> /mnt/keymap
fi

if [[ "$EFI" == "yes" ]]; then
    touch /mnt/efimode
else
    echo ${DISK} > /mnt/diskn
fi

arch-chroot /mnt /continue.sh 2>&1 | tee /mnt/var/citrine.chroot.log
rm /mnt/continue.sh

inf "Installation should now be complete."
read

