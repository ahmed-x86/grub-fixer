#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# ==============================================================================
# PROJECT: GRUB Fixer
# AUTHOR: ahmed-x86 
# 
# CHANGELOG:
# V1: Basic manual-like chroot logic for GRUB repair.
# V2: Added input validation (checks if partition exists) and loops for user input.
# V3: Added /mnt cleanup (umount -R) before starting to prevent mount conflicts.
# V4: Added 'set -e' for safety, forced Root partition input, OS detection.
# V5: Added '--removable' to grub-install to fix VM/NVRAM EFI variable issues.
#     Redirected 'read' from /dev/tty to fully support 'curl | bash' pipes.
#
# FUTURE: Support for BIOS (Legacy), LUKS, LVM, and Auto-detection.
# ==============================================================================

echo "GRUB Fixer - V5 (Bulletproof Edition)"
echo "Currently supports x86_64-efi only."
echo "Support for LUKS and LVM will be added in future updates"
echo ""

# 1. Show available disks
echo "=== Available Disks ==="
lsblk
echo "========================"
echo ""

# 2. Ask the user and store answers (with Validation)
# Notice the </dev/tty which forces read from terminal instead of stdin pipe

# Root partition is REQUIRED
echo "[*] Root partition is REQUIRED to repair the system."
while true; do
    read -p "What is the Root (/) partition name? (e.g., vda3): " root_part </dev/tty
    if [ -b "/dev/$root_part" ]; then
        break
    else
        echo "[-] Error: Partition '/dev/$root_part' does not exist. Please check lsblk and try again."
    fi
done

read -p "Did you create a /boot/efi partition? (y/n): " efi_ans </dev/tty
if [ "$efi_ans" == "y" ]; then
    while true; do
        read -p "What is the partition name? (e.g., vda1): " efi_part </dev/tty
        if [ -b "/dev/$efi_part" ]; then
            break 
        else
            echo "[-] Error: Partition '/dev/$efi_part' does not exist. Please check lsblk and try again."
        fi
    done
fi

read -p "Did you create a separate /boot partition? (y/n): " boot_ans </dev/tty
if [ "$boot_ans" == "y" ]; then
    while true; do
        read -p "What is the partition name? (e.g., vda2): " boot_part </dev/tty
        if [ -b "/dev/$boot_part" ]; then
            break
        else
            echo "[-] Error: Partition '/dev/$boot_part' does not exist. Please try again."
        fi
    done
fi

echo -e "\n[*] Executing Mount commands..."

# Clean up existing mounts (the 'if' statement safely catches the exit code of grep)
if grep -qs ' /mnt' /proc/mounts; then
    echo "-> Found existing mounts on /mnt. Cleaning up before proceeding..."
    sudo umount -R /mnt 2>/dev/null || true
fi

# 3. Execute mount commands in the correct order (Root first)
sudo mount /dev/$root_part /mnt

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

# 5. Read the distribution name safely
if [ -f "/mnt/etc/os-release" ]; then
    source /mnt/etc/os-release
    OS_NAME=$NAME
else
    echo "[-] Warning: /mnt/etc/os-release not found. Defaulting OS_NAME to 'Linux'."
    OS_NAME="Linux"
fi

echo -e "\n[*] Entering chroot and repairing GRUB automatically..."

# 6. Enter chroot and execute commands automatically using EOF
sudo chroot /mnt /bin/bash <<EOF
# Enable exit-on-error inside the chroot environment as well
set -e

echo "-> Installing for x86_64-efi platform (with --removable flag for VM support)..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$OS_NAME" --removable

echo "-> Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "-> Exiting chroot environment..."
exit
EOF

# 7. Unmount and print success message
echo -e "\n[*] Unmounting filesystems..."
sudo umount -R /mnt

echo -e "\n🎉 The operation was successful! GRUB bootloader has been repaired successfully."