# 🛠️ GRUB Fixer (V9 - Btrfs & Smart Detection Edition)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on UEFI Linux systems. **V9** evolves the tool to support complex filesystems like Btrfs out-of-the-box, making it a highly secure, intelligent **Rescue Suite** for both beginners and power users (Arch/Fedora).

## 🚀 Usage

You can choose between the quick one-liner or the manual download method depending on your environment.

### Option 1: Quick One-Liner (Recommended)
Run the script directly without downloading:
```bash
curl -sL [https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh](https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh) | sudo bash
```

### Option 2: Manual Download & Execute
If you prefer to have the file locally or the one-liner doesn't suit your environment:
```bash
curl -O [https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh](https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh)
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh
```

---

## ✨ New in V9 (The Btrfs & Smart Routing Update)
* **Dynamic Btrfs Subvolumes Support:** Automatically detects if the target Root partition is `btrfs` and launches an interactive, smart loop to mount required subvolumes (e.g., `@`, `@home`, `@log`) before chrooting. 
* **Smart Mount Routing:** Prevents user error by automatically translating standard mount points to their chroot equivalents (e.g., inputting `/` automatically mounts to `/mnt`).

## 🛡️ Features from V8 (The Smart & Secure Update)
* **Smart EFI Validation:** Actively verifies the existence of the `/EFI` directory by temporarily mounting candidates in `/tmp`, preventing accidental GRUB installations on random USB drives. 
* **Blackbox Logging System:** Automatically captures and logs all standard output and errors directly to `/var/log/grub-fixer.log` for a complete forensic troubleshooting trail.
* **Fail-Fast Root Validation:** Instantly halts execution cleanly if the script is not initiated with `sudo` (`$EUID` check).

## 💎 Core Rescue Features (V7 & Below)
* **Custom Volume Support:** Dynamically mount additional external partitions (e.g., a separate `/home` drive) during the repair process.
* **Intelligent Auto-Detection:** Scans partitions using `lsblk` and `awk` to suggest the most likely **Root (/)**. Detects filesystems without mounting for a lightning-fast pre-scan.
* **VM & NVRAM Rescue:** Uses the `--removable` flag to guarantee booting on Virtual Machines and stubborn UEFI firmware that drop NVRAM variables.
* **Pipeline Ready:** Redirected `read` commands to `/dev/tty`, making it 100% compatible with `curl | bash` pipelines.
* **Safety & Cleanup:** Forced `set -e` for immediate halt on errors and automatic `umount -R` cleanup to prevent mount conflicts.

---

## 📋 Requirements
* **Environment:** Live Linux ISO/USB (Arch, Ubuntu, Fedora, etc.).
* **Architecture:** Target system must be UEFI (`x86_64-efi`).
* **Privileges:** Sudo/Root access required.

## 🛠️ Planned for Future Updates
* **BIOS (Legacy) Support.**
* **LUKS (Encryption) & LVM Support.**
* **Full `fstab` Parsing:** For automatic detection and mounting of complex setups without prompting the user.

## ⚠️ Disclaimer
This tool is currently intended for **UEFI** systems. Always verify the auto-detected partitions and subvolumes before confirming the repair process.

---
