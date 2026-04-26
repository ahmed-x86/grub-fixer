#!/bin/bash
# ==============================================================================
# PROJECT: GRUB Fixer (V26 Modular)
# MODULE: secureboot.sh
# DESCRIPTION: Handles Secure Boot state detection, dynamic MOK OTP generation,
#              and sbctl/Shim signing integration for both Local and Chroot modes.
# ==============================================================================

check_secure_boot_state() {
    # [V22] Secure Boot Detection
    local IS_ENABLED=0
    if command -v mokutil &> /dev/null; then
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            IS_ENABLED=1
            # Note: Echoing directly to stderr to not interfere with function return if captured
            echo -e "\n[!] V22 Secure Boot Detected: ENABLED" >&2
        fi
    fi
    echo "$IS_ENABLED"
}

enroll_mok_insitu() {
    local SECURE_BOOT_ENABLED=$1
    local LOCAL_BOOT_MODE=$2
    local LOCAL_EFI_MNT=$3
    local OS_NAME=$4

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
}

generate_chroot_mok_otp() {
    local SECURE_BOOT_ENABLED=$1
    local BOOT_MODE=$2
    local CHROOT_OTP=""
    
    # [V23 SEC-2] Generate random MOK OTP before entering chroot (if Secure Boot is active)
    if [ "$SECURE_BOOT_ENABLED" -eq 1 ] && [ "$BOOT_MODE" == "efi" ]; then
        CHROOT_OTP=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)
    fi
    echo "$CHROOT_OTP"
}

get_chroot_secureboot_script() {
    # Generates the exact payload snippet to be injected into the main chroot EOF block
    local MOK_OTP=$1
    local efi_mount_path=$2
    local OS_NAME=$3
    local SECURE_BOOT_ENABLED=$4
    local BOOT_MODE=$5

    cat <<SECURE_BOOT_EOF
# [V22/V23 SEC-2] MOK Enrollment with randomly generated OTP
if [ "$SECURE_BOOT_ENABLED" -eq 1 ] && [ "$BOOT_MODE" == "efi" ]; then
    if command -v mokutil &> /dev/null && [ -f /var/lib/shim-signed/mok/MOK.der ]; then
         echo "-> Enrolling MOK for Secure Boot (Using randomly generated OTP)..."
         printf '%s\n%s\n' "$MOK_OTP" "$MOK_OTP" | mokutil --import /var/lib/shim-signed/mok/MOK.der || true
         echo -e "\n========================================================"
         echo "⚠️ SECURE BOOT MOK ENROLLMENT REQUIRED ⚠️"
         echo "1. Upon reboot, a blue screen (MokManager) will appear."
         echo "2. Select 'Enroll MOK' -> 'Continue'."
         echo "3. Enter the One-Time Password: $MOK_OTP"
         echo "   (Write this down before rebooting!)"
         echo "This is required ONCE to authorize GRUB in your Motherboard."
         echo "========================================================"
    elif command -v sbctl &> /dev/null; then
         echo "-> Arch Linux 'sbctl' detected. Attempting to sign GRUB..."
         sbctl sign -s "$efi_mount_path/EFI/$OS_NAME/grubx64.efi" || true
    fi
fi
SECURE_BOOT_EOF
}