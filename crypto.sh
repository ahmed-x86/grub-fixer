#!/bin/bash
# ==============================================================================
# PROJECT: GRUB Fixer (V27 Modular)
# MODULE: crypto.sh
# DESCRIPTION: Handles LUKS detection, decryption, LVM activation, GRUB Cryptodisk
#              injection, and secure relocking.
# ==============================================================================

early_luks_decryption() {
    local IS_LIVE=$1
    local AUTO_CONFIRM=$2

    # ==============================================================================
    # [V21] EARLY LUKS ENCRYPTION DETECTION & DECRYPTION
    # ==============================================================================
    HAS_LUKS=0
    if lsblk -o FSTYPE | grep -q "crypto_LUKS"; then
        HAS_LUKS=1
    fi

    if [ $HAS_LUKS -eq 1 ] && [ $IS_LIVE -eq 1 ]; then
        echo -e "\n[*] V21 Intelligence: Encrypted (LUKS) partitions detected!"
        LUKS_PARTS=($(lsblk -l -o NAME,FSTYPE | awk '$2=="crypto_LUKS" {print $1}'))
        
        if [ $AUTO_CONFIRM -eq 1 ]; then
            echo "[-] Auto mode active. Cannot interactively decrypt LUKS. Assuming they are already unlocked..."
        else
            read -p "-> Do you want to unlock them now to find your system? (y/n): " luks_ans </dev/tty
            if [[ "$luks_ans" == "y" || "$luks_ans" == "Y" ]]; then
                if ! command -v cryptsetup &> /dev/null; then
                    echo "[-] Error: 'cryptsetup' is not installed on this Live environment."
                    echo "    Please install it (e.g., pacman -Sy cryptsetup) and run the script again."
                else
                    for l_part in "${LUKS_PARTS[@]}"; do
                        mapper_name="crypt_${l_part}"
                        if [ -b "/dev/mapper/$mapper_name" ]; then
                            echo "   [i] /dev/$l_part is already unlocked."
                        else
                            echo "-> Unlocking /dev/$l_part..."
                            # [V23 SEC-1] Hidden password input to prevent shoulder-surfing
                            read -s -p "   Enter LUKS Password for $l_part: " luks_pass </dev/tty
                            echo "" # Newline after hidden input
                            echo -n "$luks_pass" | sudo cryptsetup luksOpen "/dev/$l_part" "$mapper_name" -
                            unset luks_pass # Clear password from memory immediately
                            if [ $? -eq 0 ]; then
                                echo "   [+] Successfully unlocked to /dev/mapper/$mapper_name"
                            else
                                echo "   [-] Failed to unlock /dev/$l_part. Please check the password."
                            fi
                        fi
                    done
                    
                    echo "[*] Scanning for Logical Volumes (LVM) inside unlocked partitions..."
                    if command -v vgchange &> /dev/null; then
                        sudo vgchange -ay || true
                    else
                        echo "   [i] 'lvm2' not found on Live USB. Skipping LVM scan."
                    fi
                fi
            fi
        fi
    fi
}

enable_cryptodisk_insitu() {
    local HAS_LUKS=$1
    # [V21] Write Cryptodisk Flag
    if [ "$HAS_LUKS" -eq 1 ]; then
        echo "-> Enabling LUKS support in GRUB (GRUB_ENABLE_CRYPTODISK=y)..."
        if [ -f /etc/default/grub ]; then
            sed -i '/GRUB_ENABLE_CRYPTODISK/d' /etc/default/grub
            echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
        fi
    fi
}

get_chroot_cryptodisk_script() {
    local HAS_LUKS=$1
    # Generates the snippet to be injected into the chroot EOF block for LUKS support
    cat <<CRYPTODISK_EOF
# [V21] Write Cryptodisk Flag
if [ "$HAS_LUKS" -eq 1 ]; then
    echo "-> Enabling LUKS support in GRUB (GRUB_ENABLE_CRYPTODISK=y)..."
    if [ -f /etc/default/grub ]; then
        sed -i '/GRUB_ENABLE_CRYPTODISK/d' /etc/default/grub
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
    fi
fi
CRYPTODISK_EOF
}

relock_luks_securely() {
    local HAS_LUKS=$1
    local IS_LOCAL=$2
    # [V21] Relock LUKS securely
    if [ "$HAS_LUKS" -eq 1 ] && [ "$IS_LOCAL" -eq 0 ]; then
        echo "[*] Relocking LUKS partitions to secure your data..."
        if command -v vgchange &> /dev/null; then
            sudo vgchange -an 2>/dev/null || true
        fi
        for l_part in $(lsblk -l -o NAME,FSTYPE | awk '$2=="crypto_LUKS" {print $1}'); do
            mapper_name="crypt_${l_part}"
            if [ -b "/dev/mapper/$mapper_name" ]; then
                sudo cryptsetup luksClose "$mapper_name" 2>/dev/null || true
            fi
        done
    fi
}