#!/bin/bash

if [[ "$EUID" != "0" ]]; then
    echo "Run as root"
    exit 1
fi

printf "Do you need a keyboard layout other than standard US? (y/N): "
read KBD
if [[ "$KBD" == "y" || "$KBD" == "Y" ]]; then
    echo "We're going to show the list of keymaps in less. Do you know how to exit less? (Y/n): "
    read UL
    if [[ "$UL" == "n" ]]; then
        echo "Once we enter less, use arrows to scroll, and q to quit once you've found the right file."
        echo "Press enter to go"
        read
    fi
    ls /usr/share/kbd/keymaps/**/*.map.gz | less
    printf "Correct keymap (omit /usr/share/kbd/keymaps and the file extension): "
    read KMP
    loadkeys ${KMP}
fi


fdisk -l | grep Disk | grep sectors --color=never

printf "Install target (will be WIPED COMPLETELY): "
read DISK

if [[ $DISK == *"nvme"* ]]; then
    echo "Seems like this is an NVME disk. Noting"
    NVME="yes"
else
    NVME="no"
fi

if ls /sys/firmware/efi/efivars > /dev/null; then
    echo "Seems like this machine was booted with EFI. Noting"
    EFI="yes"
else
    EFI="no"
fi

echo "Setting system clock via network"
timedatectl set-ntp true

echo "Partitioning disk"
if [[ "$EFI" == "yes" ]]; then
    (
        echo "g"
        echo "n"
        echo
        echo
        echo "+200M"
        echo "t"
        echo "1"
        echo "n"
        echo
        echo
        echo
        echo "w"
    ) | fdisk $DISK
    echo "Partitioned ${DISK} as an EFI volume"
else
    (
        echo "o"
        echo "n"
        echo 
        echo
        echo
        echo "w"
    ) | fdisk $DISK
    echo "Partitioned ${DISK} as an MBR volume"
fi

if [[ "$NVME" == "yes" ]]; then
    if [[ "$EFI" == "yes" ]]; then
        echo "Initializing ${DISK} as NVME EFI"
        mkfs.vfat ${DISK}p1
        mkfs.ext4 ${DISK}p2
        mount ${DISK}p2 /mnt
        mkdir -p /mnt/efi
        mount ${DISK}p1 /mnt/efi
    else
        echo "Initializing ${DISK} as NVME MBR"
        mkfs.ext4 ${DISK}p1
        mount ${DISK}p1 /mnt
    fi
else
    if [[ "$EFI" == "yes" ]]; then
        echo "Initializing ${DISK} as EFI"
        mkfs.vfat ${DISK}1
        mkfs.ext4 ${DISK}2
        mount ${DISK}2 /mnt
        mkdir -p /mnt/efi
        mount ${DISK}1 /mnt/efi
    else
        echo "Initializing ${DISK} as MBR"
        mkfs.ext4 ${DISK}1
        mount ${DISK}1 /mnt
    fi
fi

echo "Setting up base CrystalUX System"
pacstrap /mnt base linux linux-firmware networkmanager grub crystal-grub-theme man-db man-pages texinfo nano sudo curl archlinux-keyring
if [[ "$EFI" == "yes" ]]; then
    echo "Installing EFI support package"
    pacstrap /mnt efibootmgr
fi

# Grub theme & branding kek
sed -i 's/Arch/CrystalUX/g' /mnt/etc/default/grub
sed -i 's/\/path\/to\/gfxtheme/\/usr\/share\/grub\/themes\/crystalux\/theme.txt/g' /mnt/etc/default/grub
sed -i 's/#GRUB_THEME/GRUB_THEME/g' /mnt/etc/default/grub
echo "Performing minor tweaks"
sed -i 's/Arch Linux/CrystalUX/g' /etc/issue
cd /etc/ && curl -LO https://raw.githubusercontent.com/crystalux-project/iso/main/os-release
cd /usr/lib/ && curl -LO https://raw.githubusercontent.com/crystalux-project/iso/main/os-release

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

cp /etc/pacman.conf /mnt/etc/.

arch-chroot /mnt /continue.sh
rm /mnt/continue.sh

reboot