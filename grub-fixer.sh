#!/bin/bash
# ==============================================================================
# PROJECT: GRUB Fixer
# AUTHOR: ahmed-x86 
# VERSION: V26 (The Modular Update)
# CHANGELOG: See CHANGELOG.md for the full version history (V1 to V26).
# ==============================================================================

# ==============================================================================
# 1. CORE VARIABLES & FLAGS
# ==============================================================================
FORCE_ENV=""
AUTO_CONFIRM=0
API_MODE=0
API_MAP_STD=""
API_MAP_BTRFS=""

# Arrays & State Variables used across modules
declare -a custom_parts
declare -a custom_mounts
declare -a API_BTRFS_SUBVOLS
declare -a API_BTRFS_MOUNTS
root_part=""
boot_part=""
boot_ans="n"
efi_part=""
efi_mount_path=""
efi_ans="n"
BOOT_MODE="legacy"
IS_LOCAL=0
PRO_MODE_ACCEPTED=0
V17_CONFIRM_ANS=""

# ==============================================================================
# 2. THE SMART MODULE LOADER
# ==============================================================================
# This logic ensures the script works whether cloned locally or piped via curl
MODULES_DIR="/tmp/grub-fixer-modules"
REPO_URL="https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main" # Adjust 'main' if using a specific branch

load_module() {
    local mod_name="$1"
    
    # Check if the module exists locally (e.g., user cloned the repo)
    if [ -f "./$mod_name" ]; then
        source "./$mod_name"
    # Otherwise, download it on-the-fly (e.g., user ran curl | bash)
    else
        mkdir -p "$MODULES_DIR"
        # Download silently, exit if curl fails
        if ! curl -sL "$REPO_URL/$mod_name" -o "$MODULES_DIR/$mod_name"; then
            echo "[-] CRITICAL ERROR: Failed to download required module: $mod_name" >&2
            echo "    Ensure you have an active internet connection if running via curl pipe." >&2
            exit 1
        fi
        source "$MODULES_DIR/$mod_name"
    fi
}

# ==============================================================================
# 3. FLAG PARSING (Handled here to control the main flow)
# ==============================================================================
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version|-v)
            echo "GRUB Fixer V26 (The Modular Update)"
            exit 0
            ;;
        --sys-info|--json-scan)
            # Route to API module
            load_module "api.sh"
            handle_api_endpoints "$1"
            exit 0
            ;;
        --map-std)
            API_MODE=1
            API_MAP_STD="$2"
            shift 2
            ;;
        --map-btrfs)
            API_MODE=1
            API_MAP_BTRFS="$2"
            shift 2
            ;;
        -env|--env)
            if [[ "$2" == "l" || "$2" == "live" ]]; then FORCE_ENV="live"; shift 2
            elif [[ "$2" == "h" || "$2" == "host" ]]; then FORCE_ENV="host"; shift 2
            else echo "[-] Invalid argument for -env." >&2; exit 1; fi
            ;;
        -auto|--auto)
            AUTO_CONFIRM=1
            shift
            ;;
        *)
            echo "[-] Unknown parameter: $1" >&2
            exit 1
            ;;
    esac
done

# Ensure script is run as root before repair logic (Moved to fix --version/API)
if [[ $EUID -ne 0 ]]; then
   echo "[-] Error: This script must be run as root. Please use sudo." >&2
   exit 1
fi

echo "[*] Initializing GRUB Fixer V26 Engine..." >&2
load_module "api.sh"
load_module "ui.sh"
load_module "crypto.sh"
load_module "core_scan.sh"
load_module "secureboot.sh"

set -e # Exit immediately if a command exits with a non-zero status.

# ==============================================================================
# 4. MAIN EXECUTION FLOW
# ==============================================================================
START_TIME=$(date +%s)

# From ui.sh
setup_logging_and_header
show_available_disks

# Safety cleanup
if grep -qs ' /tmp/grub-fixer-scan' /proc/mounts; then
    sudo umount -R /tmp/grub-fixer-scan 2>/dev/null || true
fi

# From core_scan.sh & api.sh
detect_environment

# From crypto.sh
early_luks_decryption "$IS_LIVE" "$AUTO_CONFIRM"

# Execute logic from api.sh (Overrides normal flow if maps are provided)
apply_api_mapping_override

# If API_MODE didn't take over, run standard scanning from core_scan.sh
if [ "$API_MODE" -eq 0 ]; then
    perform_deep_scan_and_prompt
fi

# From core_scan.sh
execute_insitu_repair
execute_tier_1_fstab_mounts
execute_tier_2_3_fallback_mounts

# --- CHROOT PREP ---
prepare_chroot_environment
perform_chroot_health_check
extract_target_disk_legacy
detect_uefi_bitness

# From secureboot.sh
SECURE_BOOT_CHROOT_OTP=$(generate_chroot_mok_otp "$SECURE_BOOT_ENABLED" "$BOOT_MODE")
# Backup config
GRUB_BACKUP_CMD=""
if sudo chroot /mnt /bin/bash -c "[ -f /etc/default/grub ]"; then
    GRUB_BACKUP_TS=$(date +%s)
    GRUB_BACKUP_CMD="cp /etc/default/grub /etc/default/grub.bak.${GRUB_BACKUP_TS} && echo '[+] Backed up /etc/default/grub' >&2"
fi

echo -e "\n[*] Entering chroot and repairing GRUB automatically for: $OS_NAME" >&2
echo "[*] Detected Boot Mode: ${BOOT_MODE^^}" >&2

# --- ENTER CHROOT ---
sudo chroot /mnt /bin/bash <<EOF
set -e

if [[ "$GRUB_CFG_PATH" == *grub2* ]]; then mkdir -p /boot/grub2; else mkdir -p /boot/grub; fi

if [ "$BOOT_MODE" == "efi" ]; then
    echo "-> Installing for $EFI_TARGET platform (with --removable flag for VM support)..."
    if [ "$SECURE_BOOT_ENABLED" -eq 1 ] && [[ "$TARGET_ID" =~ (debian|ubuntu|pop) ]]; then
        echo "   [i] Debian/Ubuntu based system with Secure Boot detected. Forcing UEFI Secure Boot target."
        $GRUB_INSTALL_CMD --target=$EFI_TARGET --efi-directory=$efi_mount_path --bootloader-id="$OS_NAME" --uefi-secure-boot
    else
        $GRUB_INSTALL_CMD --target=$EFI_TARGET --efi-directory=$efi_mount_path --bootloader-id="$OS_NAME" --removable
    fi
else
    echo "-> Installing GRUB for i386-pc (Legacy BIOS) on disk: $TARGET_DISK..."
    $GRUB_INSTALL_CMD --target=i386-pc "$TARGET_DISK"
fi

$GRUB_BACKUP_CMD

echo "-> Enabling OS Prober to detect other operating systems (e.g., Windows)..."
if [ -f /etc/default/grub ]; then
    sed -i '/GRUB_DISABLE_OS_PROBER/d' /etc/default/grub
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
fi

$(get_chroot_cryptodisk_script "$HAS_LUKS")

echo "-> Generating GRUB configuration..."
$GRUB_MKCONFIG_CMD -o $GRUB_CFG_PATH

$(get_chroot_secureboot_script "$SECURE_BOOT_CHROOT_OTP" "$efi_mount_path" "$OS_NAME" "$SECURE_BOOT_ENABLED" "$BOOT_MODE")

echo "-> Exiting chroot environment..."
exit
EOF

# Clear OTP
unset SECURE_BOOT_CHROOT_OTP

echo -e "\n[*] Unmounting filesystems..." >&2
sudo umount -R /mnt || true

# From crypto.sh
relock_luks_securely "$HAS_LUKS" "$IS_LOCAL"

# From ui.sh
print_success_and_timer "$START_TIME" "$BOOT_MODE" 0