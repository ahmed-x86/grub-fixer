#!/bin/bash
# ==============================================================================
# VERSION: V27 (The Modular Update)
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

fix_windows_boot_order() {
    # [V28] WINDOWS DUAL-BOOT NVRAM RECOVERY (In-Situ version)
    # A Windows Update frequently re-adds/re-promotes "Windows Boot Manager" in
    # NVRAM and silently shoves it to the front of BootOrder, which is what
    # actually makes people think "GRUB disappeared". GRUB itself is almost
    # always still on disk - it's just no longer first in boot order.
    # This puts our freshly-installed entry back in front, without deleting
    # the Windows entry, so Windows stays reachable from the GRUB menu.
    local BOOT_MODE=$1
    local BOOTLOADER_ID=$2

    [ "$BOOT_MODE" != "efi" ] && return 0
    command -v efibootmgr &> /dev/null || return 0

    local EFI_OUT
    EFI_OUT=$(sudo efibootmgr 2>/dev/null) || return 0

    local OUR_ID
    OUR_ID=$(echo "$EFI_OUT" | grep -i -- "$BOOTLOADER_ID" | head -n1 | grep -oE '^Boot[0-9A-Fa-f]{4}' | sed 's/^Boot//')
    if [ -z "$OUR_ID" ]; then
        echo "[!] Could not locate the new NVRAM boot entry for '$BOOTLOADER_ID' - skipping boot order fix." >&2
        return 0
    fi

    if echo "$EFI_OUT" | grep -qi "Windows Boot Manager"; then
        echo "[*] Windows Boot Manager detected in NVRAM (dual-boot). Restoring '$BOOTLOADER_ID' as the default boot entry..."
    fi

    local CURRENT_ORDER
    CURRENT_ORDER=$(echo "$EFI_OUT" | grep '^BootOrder:' | cut -d: -f2 | tr -d ' \r')
    local REST
    REST=$(echo "$CURRENT_ORDER" | tr ',' '\n' | grep -v -i "^${OUR_ID}$" | paste -sd, -)
    local NEW_ORDER="$OUR_ID"
    [ -n "$REST" ] && NEW_ORDER="$OUR_ID,$REST"

    if sudo efibootmgr -o "$NEW_ORDER" &> /dev/null; then
        echo "[+] NVRAM Boot Order fixed: $NEW_ORDER (Windows entry preserved, not deleted)."
    else
        echo "[!] Warning: Failed to update NVRAM BootOrder. You may need to pick GRUB manually from the firmware boot menu once." >&2
    fi
}

get_chroot_winfix_script() {
    # [V28] Generates the equivalent snippet for the main chroot EOF block.
    # efibootmgr works fine inside the chroot since /sys is bind-mounted,
    # so NVRAM is still the host's real NVRAM.
    local BOOT_MODE=$1
    local BOOTLOADER_ID=$2

    [ "$BOOT_MODE" != "efi" ] && return 0

    cat <<WINFIX_EOF
# [V28] Windows dual-boot NVRAM recovery: re-promote our entry without
# deleting "Windows Boot Manager", in case a Windows Update reordered NVRAM.
if command -v efibootmgr &> /dev/null; then
    EFI_OUT=\$(efibootmgr 2>/dev/null)
    OUR_ID=\$(echo "\$EFI_OUT" | grep -i -- "$BOOTLOADER_ID" | head -n1 | grep -oE '^Boot[0-9A-Fa-f]{4}' | sed 's/^Boot//')
    if [ -n "\$OUR_ID" ]; then
        if echo "\$EFI_OUT" | grep -qi "Windows Boot Manager"; then
            echo "[*] Windows Boot Manager detected in NVRAM (dual-boot). Restoring '$BOOTLOADER_ID' as the default boot entry..."
        fi
        CURRENT_ORDER=\$(echo "\$EFI_OUT" | grep '^BootOrder:' | cut -d: -f2 | tr -d ' \r')
        REST=\$(echo "\$CURRENT_ORDER" | tr ',' '\n' | grep -v -i "^\${OUR_ID}\$" | paste -sd, -)
        NEW_ORDER="\$OUR_ID"
        [ -n "\$REST" ] && NEW_ORDER="\$OUR_ID,\$REST"
        if efibootmgr -o "\$NEW_ORDER" &> /dev/null; then
            echo "[+] NVRAM Boot Order fixed: \$NEW_ORDER (Windows entry preserved, not deleted)."
        else
            echo "[!] Warning: Failed to update NVRAM BootOrder." >&2
        fi
    else
        echo "[!] Could not locate the new NVRAM boot entry for '$BOOTLOADER_ID' - skipping boot order fix." >&2
    fi
fi
WINFIX_EOF
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