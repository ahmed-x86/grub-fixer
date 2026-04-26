#!/bin/bash
# ==============================================================================
# PROJECT: GRUB Fixer (V26 Modular)
# MODULE: core_scan.sh
# DESCRIPTION: The core engine for environment detection, deep scanning,
#              FSTAB parsing, fallback mounting, In-Situ execution, and Chroot prep.
# ==============================================================================

detect_environment() {
    # ==============================================================================
    # [V17/V18] ENVIRONMENT DETECTION & UNIFIED PROMPT (Kernel Parameters + fstab)
    # ==============================================================================
    KERNEL_CMD=$(cat /proc/cmdline 2>/dev/null || echo "")
    IS_LIVE=0
    ENV_STR="Real Machine"

    # V18: Respect forced environment flags if provided
    if [[ "$FORCE_ENV" == "live" ]]; then
        IS_LIVE=1
        ENV_STR="Live Environment (Forced by Flag)"
        echo -e "\n[*] V18 Flag Detected: Forcing Live Environment mode..."
    elif [[ "$FORCE_ENV" == "host" ]]; then
        IS_LIVE=0
        ENV_STR="Real Machine (Forced by Flag)"
        echo -e "\n[*] V18 Flag Detected: Forcing Host/Real Machine mode..."
    else
        # V17 Intelligence: Read kernel parameters for 100% accurate environment detection
        if [[ "$KERNEL_CMD" =~ (archiso|casper|rd\.live\.image|live-media|boot=live|isofrom|miso|cdrom|toram) ]]; then
            IS_LIVE=1
            ENV_STR="Live Environment (USB/ISO)"
        fi
        echo -e "\n[*] V17 Smart Detection: Analyzed Kernel Parameters..."
    fi
}

perform_deep_scan_and_prompt() {
    # --- STANDARD INTERACTIVE SCAN & PROMPT ---
    echo -e "\n[*] Initializing Deep Scan for system layout..."

    SCAN_MNT="/tmp/grub-fixer-scan"
    mkdir -p "$SCAN_MNT"
    FSTAB_FOUND=0
    FSTAB_PATH=""

    if [ $IS_LIVE -eq 0 ]; then
        if [ -f "/etc/fstab" ]; then
            FSTAB_FOUND=1
            FSTAB_PATH="/etc/fstab"
        fi
    else
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

        if [ $FSTAB_FOUND -eq 0 ]; then
            for part in $(lsblk -l -b -o NAME,FSTYPE,SIZE | awk '$2~/(ext4|xfs)/ {print $0}' | sort -k3 -nr | awk '{print $1}'); do
                if mount -o ro "/dev/$part" "$SCAN_MNT" 2>/dev/null; then
                    if [ -f "$SCAN_MNT/etc/fstab" ]; then FSTAB_FOUND=1; FSTAB_PATH="$SCAN_MNT/etc/fstab"; break; fi
                    umount "$SCAN_MNT" 2>/dev/null || true
                fi
            done
        fi
    fi

    # [V26 Modular Fix] Used -g to ensure arrays remain global when called from a function
    declare -g -a FSTAB_DEVS FSTAB_MNTS FSTAB_TYPES FSTAB_OPTS
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

    echo ""
    if [ $AUTO_CONFIRM -eq 1 ]; then
        echo "-> [-auto FLAG ACTIVE] Automatically confirming layout for $ENV_STR..."
        unified_ans="y"
    else
        read -p "-> Is this a $ENV_STR and is this your correct disk layout? (y/n): " unified_ans </dev/tty
    fi

    if [[ "$unified_ans" == "y" || "$unified_ans" == "Y" ]]; then
        if [ $IS_LIVE -eq 0 ]; then
            IS_LOCAL=1
            PRO_MODE_ACCEPTED=0
        else
            IS_LOCAL=0
            if [ $FSTAB_FOUND -eq 1 ]; then
                PRO_MODE_ACCEPTED=1
            else
                PRO_MODE_ACCEPTED=0
                V17_CONFIRM_ANS="y"
            fi
        fi
    else
        echo "[-] You selected 'n'. System will ask for clarification..."
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
}

execute_insitu_repair() {
    # ==============================================================================
    # [V16] IN-SITU (LOCAL) MODE DETECTION & EXECUTION
    # ==============================================================================
    if [ $IS_LOCAL -eq 1 ]; then
        echo -e "\n[*] Executing In-Situ (Local) GRUB Repair..."
        
        # Ensure all partitions in fstab are mounted (fixes missing /boot/efi)
        echo "-> Running 'mount -a' to ensure boot partitions are mounted..."
        sudo mount -a || true
        
        # [V19] Advanced OS & Command Detection
        OS_NAME="Linux"
        GRUB_INSTALL_CMD="grub-install"
        GRUB_MKCONFIG_CMD="grub-mkconfig"
        GRUB_CFG_PATH="/boot/grub/grub.cfg"

        if [ -f "/etc/os-release" ]; then
            source /etc/os-release  # Safe: sourcing local running system's own file
            OS_NAME=$NAME
            # Detect RedHat/Fedora family
            if [[ "$ID" =~ (fedora|rhel|centos|rocky|almalinux) || "$ID_LIKE" =~ (fedora|rhel|centos) ]]; then
                echo "[i] RedHat/Fedora family detected. Switching to grub2 commands."
                GRUB_INSTALL_CMD="grub2-install"
                GRUB_MKCONFIG_CMD="grub2-mkconfig"
                GRUB_CFG_PATH="/boot/grub2/grub.cfg"
                sudo mkdir -p /boot/grub2
            else
                sudo mkdir -p /boot/grub
            fi
        fi

        # [V22] Secure Boot Detection (In-Situ)
        SECURE_BOOT_ENABLED=0
        if command -v mokutil &> /dev/null; then
            if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
                SECURE_BOOT_ENABLED=1
                echo -e "\n[!] V22 Secure Boot Detected: ENABLED"
            fi
        fi

        # [V20/V21/V22] In-Situ Health Check
        echo -e "\n[*] Performing In-Situ Health Check..."
        MISSING_PKGS=()
        if ! command -v $GRUB_INSTALL_CMD &> /dev/null; then MISSING_PKGS+=("grub2" "grub"); fi
        if ! command -v os-prober &> /dev/null; then MISSING_PKGS+=("os-prober"); fi
        if [ "$HAS_LUKS" -eq 1 ] && ! command -v cryptsetup &> /dev/null; then MISSING_PKGS+=("cryptsetup"); fi
        
        # V22: Check for shim if Secure Boot is enabled (Debian/Ubuntu/Fedora logic)
        if [ "$SECURE_BOOT_ENABLED" -eq 1 ]; then
            if ! command -v mokutil &> /dev/null; then MISSING_PKGS+=("mokutil"); fi
            echo "   [i] Ensure packages like 'shim', 'shim-signed', or 'grub-efi-amd64-signed' are installed for your distro."
        fi

        # Check for EFI or Legacy locally
        if [ -d "/sys/firmware/efi" ]; then
            LOCAL_BOOT_MODE="efi"
            if ! command -v efibootmgr &> /dev/null; then MISSING_PKGS+=("efibootmgr"); fi
            
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
            
        else
            LOCAL_BOOT_MODE="legacy"
            # Find the physical disk of the root partition dynamically
            ROOT_DEV=$(findmnt -n -o SOURCE / | head -n 1)
            
            # [V21/V25] Smarter Parent Disk Extraction for nested LUKS/LVM in Legacy Mode
            PARENT_1=$(lsblk -no PKNAME "$ROOT_DEV" | head -n 1)
            PARENT_2=$(lsblk -no PKNAME "/dev/$PARENT_1" 2>/dev/null | head -n 1)
            
            if [ -n "$PARENT_2" ]; then
                TARGET_DISK="/dev/$PARENT_2"
            elif [ -n "$PARENT_1" ]; then
                TARGET_DISK="/dev/$PARENT_1"
            else
                TARGET_DISK="$ROOT_DEV"
                # [V25] Regex fallback for VMs/VirtIO where lsblk PKNAME topology fails
                if [[ "$TARGET_DISK" =~ ^(/dev/[a-zA-Z]+)[0-9]+$ ]]; then
                    TARGET_DISK="${BASH_REMATCH[1]}"
                elif [[ "$TARGET_DISK" =~ ^(/dev/(nvme[0-9]+n[0-9]+|mmcblk[0-9]+))p[0-9]+$ ]]; then
                    TARGET_DISK="${BASH_REMATCH[1]}"
                fi
            fi
        fi

        # [V20] In-Situ Package Installation
        if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
            echo "[-] Warning: Missing required packages: ${MISSING_PKGS[*]}"
            if [ $AUTO_CONFIRM -eq 1 ]; then
                install_ans="y"
            else
                read -p "-> Do you want me to attempt installing them? (y/n): " install_ans </dev/tty
            fi
            
            if [[ "$install_ans" == "y" || "$install_ans" == "Y" ]]; then
                if command -v pacman &> /dev/null; then sudo pacman -Sy --noconfirm ${MISSING_PKGS[*]};
                elif command -v apt-get &> /dev/null; then sudo apt-get update && sudo apt-get install -y ${MISSING_PKGS[*]};
                elif command -v dnf &> /dev/null; then sudo dnf install -y ${MISSING_PKGS[*]};
                elif command -v zypper &> /dev/null; then sudo zypper install -y ${MISSING_PKGS[*]};
                else echo "[-] Could not determine package manager. Please install them manually."; exit 1; fi
            else
                echo "[-] Repair might fail without these packages. Proceeding anyway..."
            fi
        else
             echo "[+] Health Check Passed: All required packages are installed."
        fi

        if [ "$LOCAL_BOOT_MODE" == "efi" ]; then
            echo "-> Installing for $EFI_TARGET platform on In-Situ system..."
            
            # [V22] Shim Installation Logic
            if [ "$SECURE_BOOT_ENABLED" -eq 1 ] && [[ "$ID" =~ (debian|ubuntu|pop) ]]; then
                echo "   [i] Debian/Ubuntu based system with Secure Boot detected. Forcing UEFI Secure Boot target."
                $GRUB_INSTALL_CMD --target=$EFI_TARGET --efi-directory=$LOCAL_EFI_MNT --bootloader-id="$OS_NAME" --uefi-secure-boot
            else
                $GRUB_INSTALL_CMD --target=$EFI_TARGET --efi-directory=$LOCAL_EFI_MNT --bootloader-id="$OS_NAME" --removable
            fi
        else
            echo "-> Installing GRUB for i386-pc (Legacy BIOS) on disk: $TARGET_DISK..."
            $GRUB_INSTALL_CMD --target=i386-pc "$TARGET_DISK"
        fi
        
        # [V23 SEC-3] Backup grub config before any modification
        if [ -f /etc/default/grub ]; then
            GRUB_BACKUP="/etc/default/grub.bak.$(date +%s)"
            cp /etc/default/grub "$GRUB_BACKUP"
            echo "[+] Backed up /etc/default/grub -> $GRUB_BACKUP"
        fi

        echo "-> Enabling OS Prober..."
        if [ -f /etc/default/grub ]; then
            sed -i '/GRUB_DISABLE_OS_PROBER/d' /etc/default/grub
            echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
        fi

        # [V21] Write Cryptodisk Flag
        if [ "$HAS_LUKS" -eq 1 ]; then
            echo "-> Enabling LUKS support in GRUB (GRUB_ENABLE_CRYPTODISK=y)..."
            if [ -f /etc/default/grub ]; then
                sed -i '/GRUB_ENABLE_CRYPTODISK/d' /etc/default/grub
                echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
            fi
        fi
        
        echo "-> Generating GRUB configuration..."
        $GRUB_MKCONFIG_CMD -o $GRUB_CFG_PATH
        
        # [V22/V23 SEC-2] MOK Enrollment with randomly generated OTP
        if [ "$SECURE_BOOT_ENABLED" -eq 1 ] && [ "$LOCAL_BOOT_MODE" == "efi" ]; then
            if command -v mokutil &> /dev/null && [ -f /var/lib/shim-signed/mok/MOK.der ]; then
                 # [V23 SEC-2] Generate a random OTP instead of hardcoded "1234"
                 MOK_OTP=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)
                 echo "-> Enrolling MOK for Secure Boot (Using randomly generated OTP)..."
                 printf '%s\n%s\n' "$MOK_OTP" "$MOK_OTP" | sudo mokutil --import /var/lib/shim-signed/mok/MOK.der || true
                 echo -e "\n========================================================"
                 echo "⚠️ SECURE BOOT MOK ENROLLMENT REQUIRED ⚠️"
                 echo "1. Upon reboot, a blue screen (MokManager) will appear."
                 echo "2. Select 'Enroll MOK' -> 'Continue'."
                 echo "3. Enter the One-Time Password: $MOK_OTP"
                 echo "   (Write this down before rebooting!)"
                 echo "This is required ONCE to authorize GRUB in your Motherboard."
                 echo "========================================================"
                 unset MOK_OTP
            elif command -v sbctl &> /dev/null; then
                 echo "-> Arch Linux 'sbctl' detected. Attempting to sign GRUB..."
                 sudo sbctl sign -s "$LOCAL_EFI_MNT/EFI/$OS_NAME/grubx64.efi" || true
            fi
        fi

        # In-Situ success UI will be called directly in the main script now
        print_success_and_timer "$START_TIME" "$LOCAL_BOOT_MODE" 1
    fi
}

execute_tier_1_fstab_mounts() {
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
                # [V25] Check if subvol is empty to prevent mount crash
                if [ -n "$r_subvol" ]; then
                    sudo mount -o subvol="$r_subvol" "$r_dev" /mnt
                else
                    sudo mount "$r_dev" /mnt
                fi
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
                    # [V25] Check if subvol is empty to prevent mount crash
                    if [ -n "$c_subvol" ]; then
                        sudo mount -o subvol="$c_subvol" "$c_dev" "/mnt$c_mnt"
                    else
                        sudo mount "$c_dev" "/mnt$c_mnt"
                    fi
                else
                    sudo mount "$c_dev" "/mnt$c_mnt"
                fi
                
                # Detect if EFI from FSTAB
                # [V23 BUG-2] efi_ans is now set here when EFI is found in fstab
                if [[ "$c_type" == "vfat" && ("$c_mnt" == "/boot" || "$c_mnt" == "/boot/efi") ]]; then
                    BOOT_MODE="efi"
                    efi_mount_path="$c_mnt"
                    efi_ans="y"
                fi
            done
            
            # If FSTAB didnt have explicitly vfat /boot or /boot/efi but EFI is needed, we set a default
            if [ -z "$efi_mount_path" ]; then
                efi_mount_path="/boot/efi" 
            fi
        fi
    fi
}

execute_tier_2_3_fallback_mounts() {
    # ==============================================================================
    # TIER 2 & 3: FALLBACK TO V10 LOGIC (Auto-Detect / Manual)
    # ==============================================================================
    if [ $PRO_MODE_ACCEPTED -eq 0 ]; then
        if [ "$API_MODE" -eq 0 ]; then
            echo -e "\n[*] Scanning partitions for Smart Auto-Detection..."

            # Smart Detect EFI Partition: Mount vfat partitions temporarily to check for /EFI directory
            AUTO_EFI=""
            TMP_EFI_MNT="/tmp/grub-fixer-efi-check"
            mkdir -p "$TMP_EFI_MNT"

            for part in $(lsblk -l -o NAME,FSTYPE | awk '$2=="vfat" {print $1}'); do
                if mount -o ro /dev/$part "$TMP_EFI_MNT" 2>/dev/null; then
                    if [ -d "$TMP_EFI_MNT/EFI" ]; then
                        AUTO_EFI="$part"
                        umount "$TMP_EFI_MNT" 2>/dev/null || true
                        break 
                    fi
                    umount "$TMP_EFI_MNT" 2>/dev/null || true
                fi
            done
            rm -rf "$TMP_EFI_MNT"

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
                    
                    if [ $AUTO_CONFIRM -eq 1 ]; then
                        efi_mount_path="/boot"
                        echo "[+] [-auto FLAG] Assuming EFI mount path: $efi_mount_path"
                    else
                        echo ""
                        echo "[?] IMPORTANT: Where does your system mount the EFI partition?"
                        read -p "-> Enter mount path (e.g., /boot or /boot/efi) [default: /boot]: " efi_mount_path </dev/tty
                        efi_mount_path=${efi_mount_path:-/boot}
                    fi
                else
                    BOOT_MODE="legacy"
                    efi_ans="n"
                fi
                
                boot_ans="n"
            else
                # --- FALLBACK: MANUAL INPUT ---
                echo "[-] Falling back to Manual Input..."
                echo ""
                
                echo "[*] Root partition is REQUIRED to repair the system."
                while true; do
                    read -p "What is the Root (/) partition name? (e.g., vda3): " root_part </dev/tty
                    if [ -b "/dev/$root_part" ]; then
                        break
                    else
                        echo "[-] Error: Partition '/dev/$root_part' does not exist."
                    fi
                done

                read -p "Did you create an EFI partition? (y/n): " efi_ans </dev/tty
                if [ "$efi_ans" == "y" ]; then
                    BOOT_MODE="efi"
                    while true; do
                        read -p "What is the partition name? (e.g., vda1): " efi_part </dev/tty
                        if [ -b "/dev/$efi_part" ]; then
                            read -p "-> Where should it be mounted? [default: /boot/efi]: " efi_mount_path </dev/tty
                            efi_mount_path=${efi_mount_path:-/boot/efi}
                            break 
                        else
                            echo "[-] Error: Partition '/dev/$efi_part' does not exist."
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
                            echo "[-] Error: Partition '/dev/$boot_part' does not exist."
                        fi
                    done
                fi
            fi

            echo ""
            echo "[*] Custom Volumes (Optional)"
            while true; do
                if [ $AUTO_CONFIRM -eq 1 ]; then
                    custom_ans="n"
                else
                    read -p "Do you want to mount any other partitions? (e.g., external /home) (y/n): " custom_ans </dev/tty
                fi
                
                if [[ "$custom_ans" == "y" ]]; then
                    read -p "  -> What is the partition name? (e.g., vda4): " c_part </dev/tty
                    if [ -b "/dev/$c_part" ]; then
                        read -p "  -> Where should it be mounted? (e.g., /home): " c_mount </dev/tty
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
        fi # End of Interactive input

        echo -e "\n[*] Executing Mount commands..."

        # Clean up existing mounts safely
        if grep -qs ' /mnt' /proc/mounts; then
            echo "-> Found existing mounts on /mnt. Cleaning up before proceeding..."
            sudo umount -R /mnt 2>/dev/null || true
        fi

        # --- 5. BTRFS & ROOT MOUNT LOGIC ---
        ROOT_FSTYPE=""
        [ -n "$root_part" ] && ROOT_FSTYPE=$(lsblk -n -o FSTYPE "/dev/$root_part" | head -n 1)

        if [ "$API_MODE" -eq 1 ] && [ -n "$API_MAP_BTRFS" ]; then
            echo "[*] V24 API MODE: Executing GUI Provided Btrfs Mounts..."
            for i in "${!API_BTRFS_MOUNTS[@]}"; do
                mnt_point="${API_BTRFS_MOUNTS[$i]}"
                subvol="${API_BTRFS_SUBVOLS[$i]}"
                if [ "$mnt_point" == "/" ]; then TARGET_MNT="/mnt"; else TARGET_MNT="/mnt$mnt_point"; fi
                
                echo "   [+] Mounting subvol '$subvol' to '$TARGET_MNT'..."
                sudo mkdir -p "$TARGET_MNT"
                sudo mount -o subvol="$subvol" "/dev/$root_part" "$TARGET_MNT"
            done
        elif [ "$ROOT_FSTYPE" == "btrfs" ]; then
            echo -e "\n[*] Btrfs Filesystem Detected on /dev/$root_part!"
            echo "[i] Please enter your subvolumes and their mount points (separated by a space)."
            
            while true; do
                read -p "-> Enter subvolume and mount point: " subvol mnt_point </dev/tty
                
                if [ -z "$subvol" ] || [ -z "$mnt_point" ]; then
                    echo "[-] Error: You must enter BOTH the subvolume and the mount point. Try again."
                    continue
                fi
                
                if [ "$mnt_point" == "/" ]; then TARGET_MNT="/mnt"; else
                    if [[ "$mnt_point" != /* ]]; then mnt_point="/$mnt_point"; fi
                    TARGET_MNT="/mnt$mnt_point"
                fi
                
                echo "   [+] Mounting subvolume '$subvol' to '$TARGET_MNT'..."
                sudo mkdir -p "$TARGET_MNT"
                sudo mount -o subvol="$subvol" "/dev/$root_part" "$TARGET_MNT"
                
                while true; do
                    read -p "-> Do you have another Btrfs subvolume? (y/n): " more_btrfs </dev/tty
                    more_btrfs=$(echo "$more_btrfs" | tr '[:upper:]' '[:lower:]')
                    if [[ "$more_btrfs" == "y" || "$more_btrfs" == "n" ]]; then break; else
                        echo "   [-] Invalid input. Please type 'y' for YES or 'n' for NO."
                    fi
                done
                if [ "$more_btrfs" == "n" ]; then break; fi
            done
        else
            echo "-> Mounting Standard Root Partition (/dev/$root_part)..."
            sudo mount "/dev/$root_part" /mnt
        fi

        # Mount Boot if separated
        if [ "$boot_ans" == "y" ]; then
            echo "-> Mounting Boot Partition (/dev/$boot_part)..."
            sudo mkdir -p /mnt/boot
            sudo mount "/dev/$boot_part" /mnt/boot
        fi

        # Mount EFI
        if [ "$efi_ans" == "y" ]; then
            echo "-> Mounting EFI Partition (/dev/$efi_part) to /mnt$efi_mount_path..."
            sudo mkdir -p "/mnt$efi_mount_path"
            sudo mount "/dev/$efi_part" "/mnt$efi_mount_path"
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
}

prepare_chroot_environment() {
    # ==============================================================================
    # FINAL STAGE: CHROOT & GRUB REPAIR (Universal for all Tiers)
    # ==============================================================================
    echo -e "\n[*] Preparing the chroot environment..."

    # 6. Preparations and bind mounts
    sudo mount --bind /dev /mnt/dev
    sudo mount --bind /proc /mnt/proc
    sudo mount --bind /sys /mnt/sys
    sudo mount --bind /run /mnt/run

    # [V20] Copy resolv.conf to enable DNS resolution inside chroot
    if [ -f /etc/resolv.conf ]; then
        echo "-> Copying /etc/resolv.conf for network access inside chroot..."
        sudo cp /etc/resolv.conf /mnt/etc/resolv.conf || true
    fi

    # 7. [V19/V23 BUG-3] Read target distro info using targeted grep instead of source
    # This avoids polluting the current environment with variables from the target system.
    OS_NAME="Linux"
    GRUB_INSTALL_CMD="grub-install"
    GRUB_MKCONFIG_CMD="grub-mkconfig"
    GRUB_CFG_PATH="/boot/grub/grub.cfg"
    TARGET_ID=""
    TARGET_ID_LIKE=""

    if [ -f "/mnt/etc/os-release" ]; then
        OS_NAME=$(grep -m1 '^NAME=' /mnt/etc/os-release | cut -d= -f2- | tr -d '"')
        TARGET_ID=$(grep -m1 '^ID=' /mnt/etc/os-release | cut -d= -f2- | tr -d '"')
        TARGET_ID_LIKE=$(grep -m1 '^ID_LIKE=' /mnt/etc/os-release | cut -d= -f2- | tr -d '"')
        OS_NAME="${OS_NAME:-Linux}"

        # Detect RedHat/Fedora family inside chroot
        if [[ "$TARGET_ID" =~ (fedora|rhel|centos|rocky|almalinux) || "$TARGET_ID_LIKE" =~ (fedora|rhel|centos) ]]; then
            echo "[i] RedHat/Fedora family detected for Chroot. Switching to grub2 commands."
            GRUB_INSTALL_CMD="grub2-install"
            GRUB_MKCONFIG_CMD="grub2-mkconfig"
            GRUB_CFG_PATH="/boot/grub2/grub.cfg"
        fi
    else
        echo "[-] Warning: /mnt/etc/os-release not found. Defaulting OS_NAME to 'Linux'."
    fi

    # [V22] Secure Boot Detection (Chroot context preparation)
    SECURE_BOOT_ENABLED=0
    if command -v mokutil &> /dev/null; then
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            SECURE_BOOT_ENABLED=1
            echo -e "\n[!] V22 Secure Boot Detected: ENABLED"
        fi
    fi
}

perform_chroot_health_check() {
    # ==========================================
    # [V20/V21/V22] CHROOT HEALTH CHECK & DEPENDENCY RESOLUTION
    # ==========================================
    echo -e "\n[*] Performing Chroot Health Check..."
    MISSING_CHROOT_PKGS=()

    # Check commands inside chroot
    if ! sudo chroot /mnt /bin/bash -c "command -v $GRUB_INSTALL_CMD" &> /dev/null; then MISSING_CHROOT_PKGS+=("grub2" "grub"); fi
    if ! sudo chroot /mnt /bin/bash -c "command -v os-prober" &> /dev/null; then MISSING_CHROOT_PKGS+=("os-prober"); fi
    if [ "$HAS_LUKS" -eq 1 ] && ! sudo chroot /mnt /bin/bash -c "command -v cryptsetup" &> /dev/null; then MISSING_CHROOT_PKGS+=("cryptsetup"); fi

    if [ "$BOOT_MODE" == "efi" ]; then
        if ! sudo chroot /mnt /bin/bash -c "command -v efibootmgr" &> /dev/null; then MISSING_CHROOT_PKGS+=("efibootmgr"); fi
        
        # V22: Check for shim if Secure Boot is enabled
        if [ "$SECURE_BOOT_ENABLED" -eq 1 ]; then
            if ! sudo chroot /mnt /bin/bash -c "command -v mokutil" &> /dev/null; then MISSING_CHROOT_PKGS+=("mokutil"); fi
            echo "   [i] Ensure packages like 'shim', 'shim-signed', or 'grub-efi-amd64-signed' are installed for your distro."
        fi
    fi

    if [ ${#MISSING_CHROOT_PKGS[@]} -ne 0 ]; then
        echo "[-] Warning: Missing required packages inside the target system: ${MISSING_CHROOT_PKGS[*]}"
        if [ $AUTO_CONFIRM -eq 1 ]; then
            install_ans="y"
        else
            read -p "-> Do you want me to attempt installing them inside chroot? (y/n): " install_ans </dev/tty
        fi
        
        if [[ "$install_ans" == "y" || "$install_ans" == "Y" ]]; then
            echo "[*] Attempting to resolve dependencies..."
            # Running the package manager detection and installation inside chroot
            sudo chroot /mnt /bin/bash <<EOF
            if command -v pacman &> /dev/null; then pacman -Sy --noconfirm ${MISSING_CHROOT_PKGS[*]};
            elif command -v apt-get &> /dev/null; then apt-get update && apt-get install -y ${MISSING_CHROOT_PKGS[*]};
            elif command -v dnf &> /dev/null; then dnf install -y ${MISSING_CHROOT_PKGS[*]};
            elif command -v zypper &> /dev/null; then zypper install -y ${MISSING_CHROOT_PKGS[*]};
            else echo "[-] Could not determine package manager inside chroot. Please install manually."; exit 1; fi
EOF
        else
            echo "[-] Repair might fail without these packages. Proceeding anyway..."
        fi
    else
        echo "[+] Health Check Passed: All required packages are present in the target system."
    fi
}

extract_target_disk_legacy() {
    # ==========================================
    # [V12/V21] TARGET DISK EXTRACTION FOR LEGACY
    # ==========================================
    # lsblk -no PKNAME extracts the parent disk. V21 supports nested LUKS/LVM.
    PARENT_1=$(lsblk -no PKNAME "/dev/$root_part" | head -n 1)
    PARENT_2=$(lsblk -no PKNAME "/dev/$PARENT_1" 2>/dev/null | head -n 1)

    if [ -n "$PARENT_2" ]; then
        TARGET_DISK="/dev/$PARENT_2"
    elif [ -n "$PARENT_1" ]; then
        TARGET_DISK="/dev/$PARENT_1"
    else
        TARGET_DISK="/dev/$root_part"
        # [V25] Regex fallback for VMs/VirtIO where lsblk PKNAME topology fails
        if [[ "$TARGET_DISK" =~ ^(/dev/[a-zA-Z]+)[0-9]+$ ]]; then
            TARGET_DISK="${BASH_REMATCH[1]}"
        elif [[ "$TARGET_DISK" =~ ^(/dev/(nvme[0-9]+n[0-9]+|mmcblk[0-9]+))p[0-9]+$ ]]; then
            TARGET_DISK="${BASH_REMATCH[1]}"
        fi
    fi
}

detect_uefi_bitness() {
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
}