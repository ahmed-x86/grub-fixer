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
# V5: Added '--removable' to fix VM/NVRAM issues, and TTY Pipeline support.
# V6: Added Auto-Detection using lsblk FSTYPE without mounting.
# V7: Added dynamic support for mounting custom volumes (e.g., /home, /var).
# V8: Added Root Validation, System Logging, and Smart EFI Detection.
# V9: Added dynamic Btrfs subvolumes support with smart routing.
# V10: Bulletproof Btrfs loop (forced y/n), fixed Archinstall /boot vs /boot/efi trap.
# FUTURE: Support for BIOS (Legacy), LUKS, and full fstab parsing.
# ==============================================================================

# --- 1. ROOT VALIDATION ---
if [[ $EUID -ne 0 ]]; then
   echo "[-] Error: This script must be run as root. Please use sudo." >&2
   exit 1
fi

# --- 2. LOGGING SYSTEM ---
LOG_FILE="/var/log/grub-fixer.log"
echo "[*] Logging all operations to $LOG_FILE"
# Redirect all output (stdout and stderr) to tee, which appends to the log file and prints to screen
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "GRUB Fixer V10: Btrfs & Smart Detection"
echo "Date: $(date)"
echo "Currently supports x86_64-efi only."
echo "=========================================="
echo ""

# 3. Show available disks
echo "=== Available Disks ==="
lsblk
echo "========================"
echo ""

echo "[*] Scanning partitions for Smart Auto-Detection..."

# --- 4. SMART AUTO DETECTION LOGIC ---

# Smart Detect EFI Partition: Mount vfat partitions temporarily to check for /EFI directory
AUTO_EFI=""
TMP_EFI_MNT="/tmp/grub-fixer-efi-check"
mkdir -p "$TMP_EFI_MNT"

for part in $(lsblk -l -o NAME,FSTYPE | awk '$2=="vfat" {print $1}'); do
    # Try mounting read-only silently
    if mount -o ro /dev/$part "$TMP_EFI_MNT" 2>/dev/null; then
        if [ -d "$TMP_EFI_MNT/EFI" ]; then
            AUTO_EFI="$part"
            umount "$TMP_EFI_MNT" 2>/dev/null || true
            break # Found the real EFI partition, stop searching
        fi
        umount "$TMP_EFI_MNT" 2>/dev/null || true
    fi
done
rm -rf "$TMP_EFI_MNT"

# Detect Linux Root Candidates (ext4, btrfs, xfs) - Pick the first one as a suggestion
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
    echo "  EFI Partition   : /dev/$AUTO_EFI (Verified /EFI directory)"
else
    echo "  EFI Partition   : [NOT FOUND]"
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
        
        # [V10 Fix]: Ask where to mount EFI to catch Archinstall /boot logic
        echo ""
        echo "[?] IMPORTANT: Where does your system mount the EFI partition?"
        echo "    (If you used archinstall, it is usually /boot)"
        read -p "-> Enter mount path (e.g., /boot or /boot/efi) [default: /boot]: " efi_mount_path </dev/tty
        efi_mount_path=${efi_mount_path:-/boot}
    else
        efi_ans="n"
    fi
    
    boot_ans="n" # We assume no separate /boot if they accepted this basic layout
    
else
    # --- FALLBACK: MANUAL INPUT ---
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

    read -p "Did you create an EFI partition? (y/n): " efi_ans </dev/tty
    if [ "$efi_ans" == "y" ]; then
        while true; do
            read -p "What is the partition name? (e.g., vda1): " efi_part </dev/tty
            if [ -b "/dev/$efi_part" ]; then
                # [V10 Fix]: Ask where to mount EFI in manual mode too
                read -p "-> Where should it be mounted? (e.g., /boot or /boot/efi) [default: /boot/efi]: " efi_mount_path </dev/tty
                efi_mount_path=${efi_mount_path:-/boot/efi}
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

# --- CUSTOM VOLUMES LOGIC (Non-Btrfs external partitions) ---
declare -a custom_parts
declare -a custom_mounts

echo ""
echo "[*] Custom Volumes (Optional)"
while true; do
    read -p "Do you want to mount any other partitions? (e.g., external /home on another disk) (y/n): " custom_ans </dev/tty
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

# --- 5. BTRFS & ROOT MOUNT LOGIC ---
ROOT_FSTYPE=$(lsblk -n -o FSTYPE "/dev/$root_part" | head -n 1)

if [ "$ROOT_FSTYPE" == "btrfs" ]; then
    echo -e "\n[*] Btrfs Filesystem Detected on /dev/$root_part!"
    echo "[i] Please enter your subvolumes and their mount points (separated by a space)."
    echo "    Examples:  @ /"
    echo "               @home /home"
    echo "               @log /var/log"
    echo ""
    
    while true; do
        read -p "-> Enter subvolume and mount point: " subvol mnt_point </dev/tty
        
        # Validate input
        if [ -z "$subvol" ] || [ -z "$mnt_point" ]; then
            echo "[-] Error: You must enter BOTH the subvolume and the mount point. Try again."
            continue
        fi
        
        # Smart routing: If mount point is exactly '/', it goes to '/mnt'
        if [ "$mnt_point" == "/" ]; then
            TARGET_MNT="/mnt"
        else
            # Ensure custom mount points start with '/'
            if [[ "$mnt_point" != /* ]]; then
                mnt_point="/$mnt_point"
            fi
            TARGET_MNT="/mnt$mnt_point"
        fi
        
        echo "   [+] Mounting subvolume '$subvol' to '$TARGET_MNT'..."
        sudo mkdir -p "$TARGET_MNT"
        sudo mount -o subvol="$subvol" "/dev/$root_part" "$TARGET_MNT"
        
        # Ask if there are more subvolumes - [V10 Fix]: Bulletproof loop
        while true; do
            read -p "-> Do you have another Btrfs subvolume? (y/n): " more_btrfs </dev/tty
            more_btrfs=$(echo "$more_btrfs" | tr '[:upper:]' '[:lower:]')
            
            if [[ "$more_btrfs" == "y" || "$more_btrfs" == "n" ]]; then
                break
            else
                echo "   [-] Invalid input. Please type 'y' for YES or 'n' for NO."
            fi
        done
        
        if [ "$more_btrfs" == "n" ]; then
            break
        fi
    done
else
    # Standard mount for ext4, xfs, etc.
    echo "-> Mounting Standard Root Partition (/dev/$root_part)..."
    sudo mount "/dev/$root_part" /mnt
fi

# Mount Boot if separated
if [ "$boot_ans" == "y" ]; then
    echo "-> Mounting Boot Partition (/dev/$boot_part)..."
    sudo mkdir -p /mnt/boot
    sudo mount /dev/$boot_part /mnt/boot
fi

# Mount EFI (Dynamic path based on user input for V10)
if [ "$efi_ans" == "y" ]; then
    echo "-> Mounting EFI Partition (/dev/$efi_part) to /mnt$efi_mount_path..."
    sudo mkdir -p "/mnt$efi_mount_path"
    sudo mount /dev/$efi_part "/mnt$efi_mount_path"
fi

# Mount Custom Partitions
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

# 6. Preparations and bind mounts
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo mount --bind /run /mnt/run

# 7. Read the distribution name safely
if [ -f "/mnt/etc/os-release" ]; then
    source /mnt/etc/os-release
    OS_NAME=$NAME
else
    echo "[-] Warning: /mnt/etc/os-release not found. Defaulting OS_NAME to 'Linux'."
    OS_NAME="Linux"
fi

echo -e "\n[*] Entering chroot and repairing GRUB automatically for: $OS_NAME"

# 8. Enter chroot and execute commands automatically using EOF
sudo chroot /mnt /bin/bash <<EOF
# Enable exit-on-error inside the chroot environment as well
set -e

echo "-> Installing for x86_64-efi platform (with --removable flag for VM support)..."
grub-install --target=x86_64-efi --efi-directory=$efi_mount_path --bootloader-id="$OS_NAME" --removable

echo "-> Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "-> Exiting chroot environment..."
exit
EOF

# 9. Unmount and print success message
echo -e "\n[*] Unmounting filesystems..."
sudo umount -R /mnt

echo -e "\n🎉 The operation was successful! GRUB bootloader has been repaired successfully."
echo "[i] A full log of this operation has been saved to: $LOG_FILE"