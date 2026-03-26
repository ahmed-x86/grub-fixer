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
# V11: Zero-Interaction Mode (fstab parser), 3-Tier Fallback System.
# V12: Added Legacy BIOS (i386-pc) support, auto-detection, and Target Disk extraction.
# V13: Added OS Prober support to automatically detect dual-boot systems (e.g., Windows).
# V14: Added Execution Timer with dynamic human-like status messages.
# V15: Added Universal UEFI Support (32-bit/i386-efi) with dynamic bitness detection.
# V16: Added In-Situ (Local) Mode to repair GRUB directly from the running system without Live USB/chroot.
# V17: Added Kernel cmdline detection for Live vs Real, and unified One-Click Confirmation prompt.
# FUTURE: Support for LUKS.
# ==============================================================================

# Start Timer for V14/V15/V16/V17
START_TIME=$(date +%s)

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
echo "GRUB Fixer V17: Ultimate Automation, Kernel Cmdline Detection, & Unified UX"
echo "Date: $(date)"
echo "Currently supports: x86_64-efi, i386-efi (32-bit) & i386-pc (Legacy)"
echo "=========================================="
echo ""

# 3. Show available disks
echo "=== Available Disks ==="
lsblk
echo "========================"
echo ""

# Cleanup any previous scan mounts safely
if grep -qs ' /tmp/grub-fixer-scan' /proc/mounts; then
    sudo umount -R /tmp/grub-fixer-scan 2>/dev/null || true
fi

# ==============================================================================
# [V17] ENVIRONMENT DETECTION & UNIFIED PROMPT (Kernel Parameters + fstab)
# ==============================================================================
KERNEL_CMD=$(cat /proc/cmdline 2>/dev/null || echo "")
IS_LIVE=0
ENV_STR="Real Machine"

# V17 Intelligence: Read kernel parameters for 100% accurate environment detection
if [[ "$KERNEL_CMD" =~ (archiso|casper|rd\.live\.image|live-media|boot=live|isofrom|miso|cdrom|toram) ]]; then
    IS_LIVE=1
    ENV_STR="Live Environment (USB/ISO)"
fi

echo -e "\n[*] V17 Smart Detection: Analyzed Kernel Parameters..."
echo "[*] Initializing Deep Scan for system layout..."

SCAN_MNT="/tmp/grub-fixer-scan"
mkdir -p "$SCAN_MNT"
FSTAB_FOUND=0
FSTAB_PATH=""

# Merge V11 intelligence (fstab parsing) at the beginning to form the unified prompt
if [ $IS_LIVE -eq 0 ]; then
    # If it's a real machine, read its files locally
    if [ -f "/etc/fstab" ]; then
        FSTAB_FOUND=1
        FSTAB_PATH="/etc/fstab"
    fi
else
    # 1. Try finding Btrfs Root (@ or @root)
    for part in $(lsblk -l -o NAME,FSTYPE | awk '$2=="btrfs" {print $1}'); do
        if mount -o ro,subvol=@ "/dev/$part" "$SCAN_MNT" 2>/dev/null; then
            if [ -f "$SCAN_MNT/etc/fstab" ]; then FSTAB_FOUND=1; FSTAB_PATH="$SCAN_MNT/etc/fstab"; break; fi
            umount "$SCAN_MNT" 2>/dev/null || true
        fi
        if mount -o ro,subvol=@root "/dev/$part" "$SCAN_MNT" 2>/dev/null; then
            if [ -f "$SCAN_MNT/etc/fstab" ]; then FSTAB_FOUND=1; FSTAB_PATH="$SCAN_MNT/etc/fstab"; break; fi
            umount "$SCAN_MNT" 2>/dev/null || true
        fi
        if mount -o ro "/dev/$part" "$SCAN_MNT" 2>/dev/null; then
            if [ -f "$SCAN_MNT/etc/fstab" ]; then FSTAB_FOUND=1; FSTAB_PATH="$SCAN_MNT/etc/fstab"; break; fi
            umount "$SCAN_MNT" 2>/dev/null || true
        fi
    done

    # 2. If no Btrfs, try ext4/xfs sorted by size
    if [ $FSTAB_FOUND -eq 0 ]; then
        for part in $(lsblk -l -b -o NAME,FSTYPE,SIZE | awk '$2~/(ext4|xfs)/ {print $0}' | sort -k3 -nr | awk '{print $1}'); do
            if mount -o ro "/dev/$part" "$SCAN_MNT" 2>/dev/null; then
                if [ -f "$SCAN_MNT/etc/fstab" ]; then FSTAB_FOUND=1; FSTAB_PATH="$SCAN_MNT/etc/fstab"; break; fi
                umount "$SCAN_MNT" 2>/dev/null || true
            fi
        done
    fi
fi

declare -a FSTAB_DEVS FSTAB_MNTS FSTAB_TYPES FSTAB_OPTS
if [ $FSTAB_FOUND -eq 1 ]; then
    echo -e "\n=== Detected System Layout (From fstab) ==="
    while read -r dev mnt type opts dump pass; do
        [[ "$dev" =~ ^#.* ]] && continue
        [[ -z "$dev" ]] && continue
        [[ "$type" =~ ^(swap|tmpfs|proc|sysfs|devtmpfs|devpts|efivarfs|cdrom)$ ]] && continue
        [[ "$mnt" == "none" ]] && continue

        real_dev="$dev"
        if [[ "$dev" == UUID=* ]]; then
            uuid_val="${dev#UUID=}"; uuid_val="${uuid_val%\"}"; uuid_val="${uuid_val#\"}"
            found_dev=$(blkid -U "$uuid_val" 2>/dev/null)
            [ -n "$found_dev" ] && real_dev="$found_dev"
        elif [[ "$dev" == PARTUUID=* ]]; then
             uuid_val="${dev#PARTUUID=}"; uuid_val="${uuid_val%\"}"; uuid_val="${uuid_val#\"}"
             found_dev=$(blkid -t PARTUUID="$uuid_val" -o device 2>/dev/null | head -n1)
             [ -n "$found_dev" ] && real_dev="$found_dev"
        fi

        FSTAB_DEVS+=("$real_dev")
        FSTAB_MNTS+=("$mnt")
        FSTAB_TYPES+=("$type")
        FSTAB_OPTS+=("$opts")
        
        if [[ "$type" == "btrfs" ]]; then
            subvol_info=$(echo "$opts" | grep -o 'subvol=[^,]*' || true)
            echo "  -> Mount: $mnt | Device: $real_dev ($type, $subvol_info)"
        else
            echo "  -> Mount: $mnt | Device: $real_dev ($type)"
        fi
    done < "$FSTAB_PATH"
    echo "==========================================="
    
    if [ "$FSTAB_PATH" == "$SCAN_MNT/etc/fstab" ]; then
        umount "$SCAN_MNT" 2>/dev/null || true
        rm -rf "$SCAN_MNT"
    fi
else
    # V6/V10 Fallback Auto-Detection if fstab is completely missing
    echo -e "\n=== Basic Auto-Detection Proposal ==="
    AUTO_ROOTS=($(lsblk -l -o NAME,FSTYPE | awk '$2~/(ext4|btrfs|xfs)/ {print $1}'))
    SUGGESTED_ROOT="${AUTO_ROOTS[0]}"
    if [ -n "$SUGGESTED_ROOT" ]; then echo "  Root (/)        : /dev/$SUGGESTED_ROOT"; else echo "  Root (/)        : [NOT FOUND]"; fi
    echo "====================================="
    if [ $IS_LIVE -eq 1 ]; then
        umount "$SCAN_MNT" 2>/dev/null || true
        rm -rf "$SCAN_MNT"
    fi
fi

# --- V17 THE UNIFIED PROMPT ---
echo ""
read -p "-> Is this a $ENV_STR and is this your correct disk layout? (y/n): " unified_ans </dev/tty

# Variables routing based on Unified Prompt
IS_LOCAL=0
PRO_MODE_ACCEPTED=0
V17_CONFIRM_ANS=""

if [[ "$unified_ans" == "y" || "$unified_ans" == "Y" ]]; then
    if [ $IS_LIVE -eq 0 ]; then
        IS_LOCAL=1
        PRO_MODE_ACCEPTED=0 # Because In-Situ executes immediately without fstab mounting
    else
        IS_LOCAL=0
        if [ $FSTAB_FOUND -eq 1 ]; then
            PRO_MODE_ACCEPTED=1 # Triggers Tier 1 execution
        else
            PRO_MODE_ACCEPTED=0
            V17_CONFIRM_ANS="y" # Triggers Tier 2 execution silently
        fi
    fi
else
    echo "[-] You selected 'n'. System will ask for clarification..."
    # Second question in case of rejection
    read -p "-> Are you using a Live Environment (L) or a Real Machine (R)? (L/R): " env_ans </dev/tty
    if [[ "$env_ans" == "L" || "$env_ans" == "l" ]]; then
        IS_LIVE=1
        IS_LOCAL=0
        echo "[*] Proceeding as Live USB (Manual Partition Selection)..."
    else
        IS_LIVE=0
        IS_LOCAL=1
        echo "[*] Proceeding as Real Machine (Local Repair)..."
    fi
    PRO_MODE_ACCEPTED=0
    V17_CONFIRM_ANS="n"
fi


# ==============================================================================
# [V16] IN-SITU (LOCAL) MODE DETECTION & EXECUTION
# ==============================================================================
# [V17 Update: The IS_LOCAL variable is now smartly managed by the Unified Prompt above. 
# The original V16 logic below is preserved but bypassed for user input.]
# CURRENT_ROOT_FS=$(findmnt -n -o FSTYPE / 2>/dev/null || echo "unknown")
# if [[ ! "$CURRENT_ROOT_FS" =~ ^(overlay|iso9660|tmpfs|squashfs|unknown)$ ]]; then
#    echo -e "\n[*] IN-SITU (LOCAL) MODE DETECTED!"
#    ...
# fi

if [ $IS_LOCAL -eq 1 ]; then
    echo -e "\n[*] Executing In-Situ (Local) GRUB Repair..."
    
    # Ensure all partitions in fstab are mounted (fixes missing /boot/efi)
    echo "-> Running 'mount -a' to ensure boot partitions are mounted..."
    sudo mount -a || true
    
    OS_NAME="Linux"
    if [ -f "/etc/os-release" ]; then
        source /etc/os-release
        OS_NAME=$NAME
    fi

    # Check for EFI or Legacy locally
    if [ -d "/sys/firmware/efi" ]; then
        LOCAL_BOOT_MODE="efi"
        
        # Super GRUB2 Disk sometimes boots without mounting efivars. We must fix this.
        if [ ! -d "/sys/firmware/efi/efivars" ] || [ -z "$(ls -A /sys/firmware/efi/efivars 2>/dev/null)" ]; then
            echo "[!] Warning: efivars not mounted. Attempting to mount efivarfs..."
            sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true
        fi
        
        # Find exactly where EFI is mounted
        LOCAL_EFI_MNT=$(findmnt -n -o TARGET -t vfat | grep -E "^/boot" | head -n 1)
        if [ -z "$LOCAL_EFI_MNT" ]; then
            echo "[-] Error: EFI system detected locally, but no vfat partition is mounted at /boot or /boot/efi."
            echo "    Please mount your EFI partition and try again."
            exit 1
        fi
        
        # Local Bitness Check
        EFI_TARGET="x86_64-efi"
        if [ -f "/sys/firmware/efi/fw_platform_size" ]; then
            EFI_SIZE=$(cat /sys/firmware/efi/fw_platform_size)
            if [ "$EFI_SIZE" == "32" ]; then
                EFI_TARGET="i386-efi"
                echo "[!] WARNING: 32-bit UEFI architecture detected locally!"
            fi
        fi
        
        echo "-> Installing for $EFI_TARGET platform on In-Situ system..."
        grub-install --target=$EFI_TARGET --efi-directory=$LOCAL_EFI_MNT --bootloader-id="$OS_NAME" --removable
    else
        LOCAL_BOOT_MODE="legacy"
        # Find the physical disk of the root partition dynamically
        ROOT_DEV=$(findmnt -n -o SOURCE / | head -n 1)
        TARGET_DISK_NAME=$(lsblk -no PKNAME "$ROOT_DEV" | head -n 1)
        if [ -z "$TARGET_DISK_NAME" ]; then
            TARGET_DISK="$ROOT_DEV"
        else
            TARGET_DISK="/dev/$TARGET_DISK_NAME"
        fi
        
        echo "-> Installing GRUB for i386-pc (Legacy BIOS) on disk: $TARGET_DISK..."
        grub-install --target=i386-pc "$TARGET_DISK"
    fi
    
    echo "-> Enabling OS Prober..."
    if [ -f /etc/default/grub ]; then
        sed -i '/GRUB_DISABLE_OS_PROBER/d' /etc/default/grub
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    fi
    
    echo "-> Generating GRUB configuration..."
    grub-mkconfig -o /boot/grub/grub.cfg
    
    echo -e "\n🎉 In-Situ operation successful! GRUB repaired locally ($LOCAL_BOOT_MODE mode)."
    
    # V14 Execution Timer
    END_TIME=$(date +%s)
    TOTAL_SECONDS=$((END_TIME - START_TIME))
    HOURS=$((TOTAL_SECONDS / 3600))
    MINUTES=$(( (TOTAL_SECONDS % 3600) / 60 ))
    SECONDS=$((TOTAL_SECONDS % 60))

    echo -e "\n⏱️  Execution Time: ${HOURS}h ${MINUTES}m ${SECONDS}s"

    if [ "$TOTAL_SECONDS" -lt 15 ]; then
        echo "Wait, did I just fix that?! You didn't even get to sip your coffee! ☕😂🏃‍♂️"
    elif [ "$TOTAL_SECONDS" -le 60 ]; then
        echo "Done and dusted! Not even the pros can speedrun a system repair like this. 🏆🔥"
    else
        echo "Took a minute, but hey... I'm the big boss, and I like to make a cinematic entrance! 👑🕶️🍿"
    fi
    
    # Exit script cleanly so it doesn't run the Live USB Chroot logic below
    exit 0 
fi

# Variables for V12 Legacy support
BOOT_MODE="legacy" # Default to legacy until proven it's EFI
efi_mount_path=""
root_part=""

# ==============================================================================
# TIER 1: PRO FSTAB AUTO-DETECTION (V11/V12)
# [V17 Update: The fstab Deep Scan logic has been successfully moved to the 
# top to feed the new Unified Prompt. The original code here is preserved 
# in structure but bypassed for execution.]
# ==============================================================================
# echo "[*] TIER 1: Initializing Deep Scan for fstab..."
# SCAN_MNT="/tmp/grub-fixer-scan"
# ...
# read -p "Is this fstab configuration 100% correct? (y/n): " pro_ans </dev/tty
# ...

# ==============================================================================
# EXECUTION: TIER 1 (PRO FSTAB)
# ==============================================================================
if [ $PRO_MODE_ACCEPTED -eq 1 ]; then
    echo -e "\n[*] Executing Automated FSTAB Mounts..."
    
    if grep -qs ' /mnt' /proc/mounts; then sudo umount -R /mnt 2>/dev/null || true; fi
    
    # Mount Root (/) first
    root_idx=-1
    for i in "${!FSTAB_MNTS[@]}"; do
        if [ "${FSTAB_MNTS[$i]}" == "/" ]; then root_idx=$i; break; fi
    done
    
    if [ $root_idx -ne -1 ]; then
        r_dev="${FSTAB_DEVS[$root_idx]}"
        root_part=$(basename "$r_dev") # Save root_part for Legacy Disk Extraction later
        r_opts="${FSTAB_OPTS[$root_idx]}"
        r_type="${FSTAB_TYPES[$root_idx]}"
        
        echo "   [+] Mounting Root (/) -> $r_dev"
        if [[ "$r_type" == "btrfs" ]]; then
            r_subvol=$(echo "$r_opts" | grep -o 'subvol=[^,]*' | cut -d= -f2 || true)
            sudo mount -o subvol="$r_subvol" "$r_dev" /mnt
        else
            sudo mount "$r_dev" /mnt
        fi
    else
        echo "[-] CRITICAL ERROR: Could not find '/' in fstab! Falling back to manual mode..."
        PRO_MODE_ACCEPTED=0 # Force fallback to TIER 2/3
    fi
    
    # Mount everything else if root succeeded
    if [ $PRO_MODE_ACCEPTED -eq 1 ]; then
        for i in "${!FSTAB_MNTS[@]}"; do
            if [ $i -eq $root_idx ]; then continue; fi
            c_dev="${FSTAB_DEVS[$i]}"
            c_mnt="${FSTAB_MNTS[$i]}"
            c_opts="${FSTAB_OPTS[$i]}"
            c_type="${FSTAB_TYPES[$i]}"
            
            if [ ! -b "$c_dev" ]; then
                echo "   [!] Warning: Device $c_dev not found. Skipping $c_mnt..."
                continue
            fi
            
            echo "   [+] Mounting $c_mnt -> $c_dev"
            sudo mkdir -p "/mnt$c_mnt"
            if [[ "$c_type" == "btrfs" ]]; then
                c_subvol=$(echo "$c_opts" | grep -o 'subvol=[^,]*' | cut -d= -f2 || true)
                sudo mount -o subvol="$c_subvol" "$c_dev" "/mnt$c_mnt"
            else
                sudo mount "$c_dev" "/mnt$c_mnt"
            fi
            
            # Detect if EFI from FSTAB
            if [[ "$c_type" == "vfat" && ("$c_mnt" == "/boot" || "$c_mnt" == "/boot/efi") ]]; then
                BOOT_MODE="efi"
                efi_mount_path="$c_mnt"
            fi
        done
        
        # If FSTAB didn't have explicitly vfat /boot or /boot/efi but EFI is needed, we set a default
        if [ -z "$efi_mount_path" ]; then
            efi_mount_path="/boot/efi" 
        fi
    fi
fi

# ==============================================================================
# TIER 2 & 3: FALLBACK TO V10 LOGIC (Auto-Detect / Manual)
# ==============================================================================
if [ $PRO_MODE_ACCEPTED -eq 0 ]; then
    echo -e "\n[*] Scanning partitions for Smart Auto-Detection..."

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

    # [V17 Update: Redundant SUGGESTED_ROOT logic is safely bypassed here 
    # since it was presented in the Unified Prompt.]

    # Ask the user based on your idea (V17: Only ask if they didn't already accept it)
    if [ "$V17_CONFIRM_ANS" == "y" ]; then
        confirm_ans="y"
        echo "[+] Using accepted basic auto-detection..."
    elif [ "$V17_CONFIRM_ANS" == "n" ]; then
        confirm_ans="n"
    else
        read -p "Is this configuration correct? (y/n): " confirm_ans </dev/tty
    fi

    if [[ "$confirm_ans" == "y" && -n "$SUGGESTED_ROOT" ]]; then
        # --- ACCEPTED AUTO-DETECTION ---
        echo "[+] Proceeding with Auto-Detected partitions..."
        root_part="$SUGGESTED_ROOT"
        
        if [ -n "$AUTO_EFI" ]; then
            BOOT_MODE="efi"
            efi_ans="y"
            efi_part="$AUTO_EFI"
            
            # [V10 Fix]: Ask where to mount EFI to catch Archinstall /boot logic
            echo ""
            echo "[?] IMPORTANT: Where does your system mount the EFI partition?"
            echo "    (If you used archinstall, it is usually /boot)"
            read -p "-> Enter mount path (e.g., /boot or /boot/efi) [default: /boot]: " efi_mount_path </dev/tty
            efi_mount_path=${efi_mount_path:-/boot}
        else
            BOOT_MODE="legacy"
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
            BOOT_MODE="efi"
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
        else
            echo "[*] No EFI selected. Assuming Legacy BIOS."
            BOOT_MODE="legacy"
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
fi # End of Tier 2 & 3 Fallback execution

# ==============================================================================
# FINAL STAGE: CHROOT & GRUB REPAIR (Universal for all Tiers)
# ==============================================================================
echo -e "\n[*] Preparing the chroot environment..."

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

# ==========================================
# [V12] TARGET DISK EXTRACTION FOR LEGACY
# ==========================================
# lsblk -no PKNAME extracts the parent disk (e.g. 'sda' from 'sda1' or 'nvme0n1' from 'nvme0n1p2')
TARGET_DISK_NAME=$(lsblk -no PKNAME "/dev/$root_part" | head -n 1)

if [ -z "$TARGET_DISK_NAME" ]; then
    # Fallback just in case it's already a whole disk or LVM
    TARGET_DISK="/dev/$root_part"
else
    TARGET_DISK="/dev/$TARGET_DISK_NAME"
fi

# ==========================================
# [V15] DYNAMIC UEFI BITNESS DETECTION
# ==========================================
EFI_TARGET="x86_64-efi" # Default to 64-bit
if [ "$BOOT_MODE" == "efi" ]; then
    if [ -f "/sys/firmware/efi/fw_platform_size" ]; then
        EFI_SIZE=$(cat /sys/firmware/efi/fw_platform_size)
        if [ "$EFI_SIZE" == "32" ]; then
            EFI_TARGET="i386-efi"
            echo "[!] WARNING: 32-bit UEFI architecture detected!"
            echo "    Setting target to: $EFI_TARGET"
            echo "    Make sure your Live USB contains 32-bit GRUB packages (e.g., grub-efi-ia32)."
        else
            EFI_TARGET="x86_64-efi"
        fi
    else
        echo "[i] /sys/firmware/efi/fw_platform_size not found. Assuming x86_64-efi."
    fi
fi

echo -e "\n[*] Entering chroot and repairing GRUB automatically for: $OS_NAME"
echo "[*] Detected Boot Mode: ${BOOT_MODE^^}"

# 8. Enter chroot and execute commands automatically using EOF
sudo chroot /mnt /bin/bash <<EOF
# Enable exit-on-error inside the chroot environment as well
set -e

if [ "$BOOT_MODE" == "efi" ]; then
    echo "-> Installing for $EFI_TARGET platform (with --removable flag for VM support)..."
    grub-install --target=$EFI_TARGET --efi-directory=$efi_mount_path --bootloader-id="$OS_NAME" --removable
else
    echo "-> Installing GRUB for i386-pc (Legacy BIOS) on disk: $TARGET_DISK..."
    grub-install --target=i386-pc "$TARGET_DISK"
fi

echo "-> Enabling OS Prober to detect other operating systems (e.g., Windows)..."
if [ -f /etc/default/grub ]; then
    sed -i '/GRUB_DISABLE_OS_PROBER/d' /etc/default/grub
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
fi

echo "-> Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "-> Exiting chroot environment..."
exit
EOF

# 9. Unmount and print success message
echo -e "\n[*] Unmounting filesystems..."
sudo umount -R /mnt || true

echo -e "\n🎉 The operation was successful! GRUB bootloader has been repaired successfully ($BOOT_MODE mode)."
echo "[i] A full log of this operation has been saved to: $LOG_FILE"

# ==============================================================================
# V14 Execution Timer & Dynamic Human Responses
# ==============================================================================
END_TIME=$(date +%s)
TOTAL_SECONDS=$((END_TIME - START_TIME))
HOURS=$((TOTAL_SECONDS / 3600))
MINUTES=$(( (TOTAL_SECONDS % 3600) / 60 ))
SECONDS=$((TOTAL_SECONDS % 60))

echo -e "\n⏱️  Execution Time: ${HOURS}h ${MINUTES}m ${SECONDS}s"

if [ "$TOTAL_SECONDS" -lt 15 ]; then
    echo "Wait, did I just fix that?! You didn't even get to sip your coffee! ☕😂🏃‍♂️"
elif [ "$TOTAL_SECONDS" -le 60 ]; then
    echo "Done and dusted! Not even the pros can speedrun a system repair like this. 🏆🔥"
else
    echo "Took a minute, but hey... I'm the big boss, and I like to make a cinematic entrance! 👑🕶️🍿"
fi