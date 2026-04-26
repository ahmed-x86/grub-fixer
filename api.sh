#!/bin/bash
# ==============================================================================
# PROJECT: GRUB Fixer (V26 Modular)
# MODULE: api.sh
# DESCRIPTION: Handles JSON outputs and explicit mapping logic for GUI/TUI integration.
# ==============================================================================

handle_api_endpoints() {
    # [V24] GUI Endpoint: Return System Info as JSON
    if [[ "$1" == "--sys-info" ]]; then
        ENV_TYPE="host"
        grep -q -E '(archiso|casper|live|miso)' /proc/cmdline 2>/dev/null && ENV_TYPE="live"
        
        BOOT_FIRMWARE="bios"
        [ -d "/sys/firmware/efi" ] && BOOT_FIRMWARE="uefi"
        
        BAT_PCT="unknown"
        if [ -d "/sys/class/power_supply/BAT0" ]; then
            BAT_PCT=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        elif [ -d "/sys/class/power_supply/BAT1" ]; then
            BAT_PCT=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null)
        fi

        printf '{"environment": "%s", "firmware": "%s", "battery_percent": "%s"}\n' "$ENV_TYPE" "$BOOT_FIRMWARE" "$BAT_PCT"
        exit 0
    fi

    # [V24] GUI Endpoint: Scan fstab/system and return layout as JSON (Bug Fixed)
    if [[ "$1" == "--json-scan" ]]; then
        JSON_OUT='{"status": "success", "partitions": ['
        SCAN_MNT="/tmp/grub-fixer-json-scan"
        mkdir -p "$SCAN_MNT"
        FSTAB_FOUND=0
        
        if grep -q -E '(archiso|casper|live|miso)' /proc/cmdline 2>/dev/null; then
            for part in $(lsblk -l -o NAME,FSTYPE | awk '$2~/(ext4|btrfs|xfs)/ {print $1}'); do
                if mount -o ro "/dev/$part" "$SCAN_MNT" 2>/dev/null; then
                    if [ -f "$SCAN_MNT/etc/fstab" ]; then FSTAB_FOUND=1; break; fi
                    umount "$SCAN_MNT" 2>/dev/null || true
                fi
            done
        else
            if [ -f "/etc/fstab" ]; then
                FSTAB_FOUND=1
                mkdir -p "$SCAN_MNT/etc" # Fixed cp directory error
                cp /etc/fstab "$SCAN_MNT/etc/fstab"
            fi
        fi

        if [ $FSTAB_FOUND -eq 1 ]; then
            FIRST=1
            while read -r dev mnt type opts dump pass; do
                [[ "$dev" =~ ^#.* || -z "$dev" || "$type" =~ ^(swap|tmpfs|proc|sysfs|none)$ ]] && continue
                
                real_dev="$dev"
                if [[ "$dev" == UUID=* ]]; then
                    uuid_val=$(echo "$dev" | cut -d= -f2- | tr -d '"'); real_dev=$(blkid -U "$uuid_val" 2>/dev/null)
                elif [[ "$dev" == PARTUUID=* ]]; then
                     uuid_val=$(echo "$dev" | cut -d= -f2- | tr -d '"'); real_dev=$(blkid -t PARTUUID="$uuid_val" -o device 2>/dev/null | head -n1)
                fi
                
                subvol=""
                if [[ "$type" == "btrfs" ]]; then subvol=$(echo "$opts" | grep -o 'subvol=[^,]*' | cut -d= -f2 || true); fi
                
                real_dev_name=$(basename "$real_dev" 2>/dev/null || echo "$real_dev")
                [ $FIRST -eq 0 ] && JSON_OUT="$JSON_OUT,"
                JSON_OUT="$JSON_OUT{\"device\": \"$real_dev_name\", \"mount\": \"$mnt\", \"type\": \"$type\", \"subvol\": \"$subvol\"}"
                FIRST=0
            done < "$SCAN_MNT/etc/fstab"
        fi
        JSON_OUT="$JSON_OUT]}"
        umount "$SCAN_MNT" 2>/dev/null || true; rm -rf "$SCAN_MNT"
        echo "$JSON_OUT"
        exit 0
    fi
}

apply_api_mapping_override() {
    # [V24] API MAPPING OVERRIDE LOGIC
    # Bypass all interactive scanning if a GUI provided a direct map.
    if [ "$API_MODE" -eq 1 ]; then
        echo -e "\n[*] V24 API MODE ACTIVE: Overriding manual scans with GUI provided layout..."
        AUTO_CONFIRM=1
        PRO_MODE_ACCEPTED=0 # Force Tier 2 layout execution without prompts
        IS_LOCAL=0          # API assumes Chroot mode for mapped partitions
        
        if [ -n "$API_MAP_STD" ]; then
            for mapping in $API_MAP_STD; do
                dev=$(echo "$mapping" | cut -d: -f1)
                role=$(echo "$mapping" | cut -d: -f2)
                mnt=$(echo "$mapping" | cut -d: -f3)
                
                if [ "$role" == "root" ]; then root_part="$dev"
                elif [ "$role" == "efi" ]; then efi_part="$dev"; efi_mount_path="$mnt"; efi_ans="y"; BOOT_MODE="efi"
                elif [ "$role" == "boot" ]; then boot_part="$dev"; boot_ans="y"
                elif [ "$role" == "ext" ]; then custom_parts+=("$dev"); custom_mounts+=("$mnt")
                fi
            done
        elif [ -n "$API_MAP_BTRFS" ]; then
            for mapping in $API_MAP_BTRFS; do
                dev=$(echo "$mapping" | cut -d: -f1)
                role=$(echo "$mapping" | cut -d: -f2)
                
                if [ "$role" == "efi" ]; then 
                    efi_part="$dev"
                    efi_mount_path=$(echo "$mapping" | cut -d: -f3)
                    efi_ans="y"
                    BOOT_MODE="efi"
                elif [ "$role" == "root" ]; then 
                    root_part="$dev"
                    subvols_raw=$(echo "$mapping" | cut -d: -f3) # e.g. "/=@,/home=@home"
                    IFS=',' read -ra SUB_ARRAY <<< "$subvols_raw"
                    for sub in "${SUB_ARRAY[@]}"; do
                        API_BTRFS_MOUNTS+=("$(echo "$sub" | cut -d= -f1)")
                        API_BTRFS_SUBVOLS+=("$(echo "$sub" | cut -d= -f2)")
                    done
                fi
            done
        fi
    fi
}