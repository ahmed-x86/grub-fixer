#!/bin/bash
# ==============================================================================
# PROJECT: GRUB Fixer (V27 Bulletproof Modular)
# MODULE: ui.sh
# DESCRIPTION: Handles logging setup, headers, disk listing, and execution timer.
# ==============================================================================

setup_logging_and_header() {
    # --- 2. LOGGING SYSTEM ---
    LOG_FILE="/var/log/grub-fixer.log"
    
    # [V27] Bulletproof fallback: If /var/log is read-only in some weird Live ISOs, use /tmp
    if ! touch "$LOG_FILE" 2>/dev/null; then
        LOG_FILE="/tmp/grub-fixer.log"
    fi
    
    echo "[*] Logging all operations to $LOG_FILE"
    # Redirect all output (stdout and stderr) to tee, which appends to the log file and prints to screen
    exec > >(tee -a "$LOG_FILE") 2>&1

    echo "=========================================="
    echo "GRUB Fixer V27: The Bulletproof Modular Update"
    echo "Date: $(date)"
    echo "Currently supports: x86_64-efi, i386-efi (32-bit) & i386-pc (Legacy)"
    echo "OS Families Supported: Debian, Arch, RedHat, Fedora, SUSE"
    echo "=========================================="
    echo ""
}

show_available_disks() {
    # 3. Show available disks
    echo "=== Available Disks ==="
    lsblk
    echo "========================"
    echo ""
}

print_success_and_timer() {
    local START_TIME=$1
    local MODE_USED=$2
    local IS_LOCAL_MODE=$3

    # Print appropriate success message based on execution mode
    if [ "$IS_LOCAL_MODE" -eq 1 ]; then
        echo -e "\n🎉 In-Situ operation successful! GRUB repaired locally ($MODE_USED mode)."
    else
        echo -e "\n🎉 The operation was successful! GRUB bootloader has been repaired successfully ($MODE_USED mode)."
        echo "[i] A full log of this operation has been saved to: $LOG_FILE"
    fi

    # ==============================================================================
    # V14/V23 Execution Timer & Dynamic Human Responses
    # [V23 BUG-1] Renamed SECONDS -> SECS_DISPLAY to avoid clash with bash reserved variable
    # ==============================================================================
    END_TIME=$(date +%s)
    TOTAL_SECONDS=$((END_TIME - START_TIME))
    HOURS=$((TOTAL_SECONDS / 3600))
    MINUTES=$(( (TOTAL_SECONDS % 3600) / 60 ))
    SECS_DISPLAY=$((TOTAL_SECONDS % 60))

    echo -e "\n⏱️  Execution Time: ${HOURS}h ${MINUTES}m ${SECS_DISPLAY}s"

    if [ "$TOTAL_SECONDS" -lt 15 ]; then
        echo "Wait, did I just fix that?! You didn't even get to sip your coffee! ☕😂🏃‍♂️"
    elif [ "$TOTAL_SECONDS" -le 60 ]; then
        echo "Done and dusted! Not even the pros can speedrun a system repair like this. 🏆🔥"
    else
        echo "Took a minute, but hey... I'm the big boss, and I like to make a cinematic entrance! 👑🕶️🍿"
    fi
    
    # Exit script cleanly
    exit 0
}