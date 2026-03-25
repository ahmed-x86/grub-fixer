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
# V6: Added Auto-Detection using lsblk FSTYPE without mounting.
# V7: Added dynamic support for mounting custom volumes (e.g., /home, /var).
# FUTURE: Support for BIOS (Legacy), LUKS, LVM, and full fstab parsing.
# ==============================================================================

echo "V7: Auto-Detection & Custom Volumes Support Edition."
echo "Currently supports x86_64-efi only."
echo "Support for LUKS and LVM will be added in future updates"
echo ""

# 1. Show available disks
echo "=== Available Disks ==="
lsblk
echo "========================"
echo ""

echo "[*] Scanning partitions for Auto-Detection..."

# --- AUTO DETECTION LOGIC ---
# Detect EFI Partition (vfat)
AUTO_EFI=$(lsblk -l -o NAME,FSTYPE | awk '$2=="vfat" {print $1}' | head -n 1)
# Detect Linux Root Candidates (ext4, btrfs, xfs) - We will pick the first one as a suggestion
AUTO_ROOTS=($(lsblk -l -o NAME,FSTYPE | awk '$2~/(ext4|btrfs|xfs)/ {print $1}'))
SUGGESTED_ROOT="${AUTO_ROOTS[0]}"

# --- UX PROPOSAL ---
echo ""
echo "=== Auto-Detection Proposal ==="
if [ -n "$SUGGESTED_ROOT" ]; then
    echo "  Root (/)        : /dev/$SUGGESTED_ROOT"
else
    echo "  Root (/)        : [NOT FOUND]"
fi

if [ -n "$AUTO_EFI" ]; then
    echo "  EFI (/boot/efi) : /dev/$AUTO_EFI"
else
    echo "  EFI (/boot/efi) : [NOT FOUND]"
fi
echo "  Boot (/boot)    : [No separate partition assumed]"
echo "==============================="
echo ""

# Ask the user based on your idea
read -p "Is this configuration correct? (y/n): " confirm_ans </dev/tty

if [[ "$confirm_ans" == "y" && -n "$SUGGESTED_ROOT" ]]; then
    # --- ACCEPTED AUTO-DETECTION ---
    echo "[+] Proceeding with Auto-Detected partitions..."
    root_part="$SUGGESTED_ROOT"
    
    if [ -n "$AUTO_EFI" ]; then
        efi_ans="y"
        efi_part="$AUTO_EFI"
    else
        efi_ans="n"
    fi
    
    boot_ans="n" # We assume no separate /boot if they accepted this basic layout
    
else
    # --- FALLBACK: V5 MANUAL INPUT (Your exact code) ---
    echo "[-] Falling back to Manual Input..."
    echo ""
    
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
fi

# --- CUSTOM VOLUMES LOGIC ---
declare -a custom_parts
declare -a custom_mounts

echo ""
echo "[*] Custom Volumes (Optional)"
while true; do
    read -p "Do you want to mount any other partitions? (e.g., /home, /var, /usr) (y/n): " custom_ans </dev/tty
    if [[ "$custom_ans" == "y" ]]; then
        read -p "  -> What is the partition name? (e.g., vda4): " c_part </dev/tty
        if [ -b "/dev/$c_part" ]; then
            read -p "  -> Where should it be mounted? (e.g., /home): " c_mount </dev/tty
            
            # Ensure the mount point starts with /
            if [[ "$c_mount" == /* ]]; then
                custom_parts+=("$c_part")
                custom_mounts+=("$c_mount")
                echo "  [+] Added: /dev/$c_part will be mounted at /mnt$c_mount"
            else
                echo "  [-] Error: Mount point must start with '/' (e.g., /var). Try again."
            fi
        else
            echo "  [-] Error: Partition '/dev/$c_part' does not exist. Try again."
        fi
    else
        break
    fi
done

echo -e "\n[*] Executing Mount commands..."

# Clean up existing mounts safely
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

# 3.5 Mount custom partitions
if [ ${#custom_parts[@]} -gt 0 ]; then
    echo "-> Mounting custom volumes..."
    for i in "${!custom_parts[@]}"; do
        c_part="${custom_parts[$i]}"
        c_mount="${custom_mounts[$i]}"
        
        sudo mkdir -p "/mnt$c_mount"
        sudo mount "/dev/$c_part" "/mnt$c_mount"
        echo "   Mounted /dev/$c_part to /mnt$c_mount"
    done
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

echo -e "\n[*] Entering chroot and repairing GRUB automatically for: $OS_NAME"

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