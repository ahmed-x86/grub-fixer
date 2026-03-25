#!/bin/bash

# 1. Show available disks
echo "=== Available Disks ==="
lsblk
echo "========================"
echo ""

# 2. Ask the user and store answers
read -p "Did you create a /boot/efi partition? (y/n): " efi_ans
if [ "$efi_ans" == "y" ]; then
    read -p "What is the partition name? (e.g., vda1): " efi_part
fi

read -p "Did you create a /boot partition? (y/n): " boot_ans
if [ "$boot_ans" == "y" ]; then
    read -p "What is the partition name? (e.g., vda2): " boot_part
fi

read -p "Did you create a root directory (/) partition? (y/n): " root_ans
if [ "$root_ans" == "y" ]; then
    read -p "What is the partition name? (e.g., vda3): " root_part
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
sudo touch /mnt/grub-fixer.txt
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo mount --bind /run /mnt/run

# 5. Read the distribution name from the broken system
# We use source to import variables from the file directly
source /mnt/etc/os-release
OS_NAME=$NAME

# 6. Write to the file (1, Architecture, OS name)
echo "1" | sudo tee /mnt/grub-fixer.txt > /dev/null
echo "x86_64-efi" | sudo tee -a /mnt/grub-fixer.txt > /dev/null
echo "$OS_NAME" | sudo tee -a /mnt/grub-fixer.txt > /dev/null

# 7. Copy the current script into the chroot to run it again later
SCRIPT_NAME=$(basename "$0")
sudo cp "$0" "/mnt/$SCRIPT_NAME"
sudo chmod +x "/mnt/$SCRIPT_NAME"

# 8. Enter the chroot jail
echo ""
read -p "Press Enter to enter the chroot environment, then run the script again..."
sudo chroot /mnt /bin/bash