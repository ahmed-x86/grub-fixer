#!/bin/bash

# ==============================================================================
# GRUB Fixer - V1
# Currently supports x86_64-efi only.
# Support for other architectures and BIOS (Legacy) will be added in future updates.
# Support for LUKS and lvm  will be added in future updates
# ==============================================================================
echo "GRUB Fixer - V2"
echo "Currently supports x86_64-efi only."
echo "Support for LUKS and lvm  will be added in future updates"
echo ""

# 1. Show available disks
echo "=== Available Disks ==="
lsblk
echo "========================"
echo ""

# 2. Ask the user and store answers (with Validation)
read -p "Did you create a /boot/efi partition? (y/n): " efi_ans
if [ "$efi_ans" == "y" ]; then
    while true; do
        read -p "What is the partition name? (e.g., vda1): " efi_part
        if [ -b "/dev/$efi_part" ]; then
            break 
        else
            echo "[-] Error: Partition '/dev/$efi_part' does not exist. Please check lsblk and try again."
        fi
    done
fi

read -p "Did you create a /boot partition? (y/n): " boot_ans
if [ "$boot_ans" == "y" ]; then
    while true; do
        read -p "What is the partition name? (e.g., vda2): " boot_part
        if [ -b "/dev/$boot_part" ]; then
            break
        else
            echo "[-] Error: Partition '/dev/$boot_part' does not exist. Please try again."
        fi
    done
fi

read -p "Did you create a root directory (/) partition? (y/n): " root_ans
if [ "$root_ans" == "y" ]; then
    while true; do
        read -p "What is the partition name? (e.g., vda3): " root_part
        if [ -b "/dev/$root_part" ]; then
            break
        else
            echo "[-] Error: Partition '/dev/$root_part' does not exist. Please try again."
        fi
    done
fi

echo -e "\n[*] Executing Mount commands..."

# 3. Execute mount commands in the correct order (Root first)
if [ "$root_ans" == "y" ]; then
    sudo mount /dev/$root_part /mnt
fi

if [ "$boot_ans" == "y" ]; then
    sudo mkdir -p /mnt/boot
    sudo mount /dev/$boot_part /mnt/boot
fi

if [ "$efi_ans" == "y" ]; then
    sudo mkdir -p /mnt/boot/efi
    sudo mount /dev/$efi_part /mnt/boot/efi
fi

echo "[*] Preparing the chroot environment..."

# 4. Preparations and bind mounts
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo mount --bind /run /mnt/run

# 5. Read the distribution name from the broken system
source /mnt/etc/os-release
OS_NAME=$NAME

echo -e "\n[*] Entering chroot and repairing GRUB automatically..."

# 6. Enter chroot and execute commands automatically using EOF
sudo chroot /mnt /bin/bash <<EOF
echo "-> Installing for x86_64-efi platform..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$OS_NAME"

echo "-> Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "-> Exiting chroot environment..."
exit
EOF

# 7. Unmount and print success message
echo -e "\n[*] Unmounting filesystems..."
sudo umount -R /mnt

echo -e "\n🎉 The operation was successful! GRUB bootloader has been repaired successfully."