# 🛠️ GRUB Fixer (V8 - Smart & Secure Edition)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on UEFI Linux systems. **V8** evolves the tool into a highly secure, intelligent **Rescue Suite**, featuring active logging, strict validations, and smart partition verification to ensure a flawless chroot environment and recovery process.

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

## ✨ New in V8 (The Smart & Secure Update)
* **Smart EFI Validation:** No longer blindly trusts any `vfat` partition. It temporarily mounts candidates in `/tmp` to actively verify the existence of the `/EFI` directory, preventing accidental GRUB installations on random USB drives. 
* **Blackbox Logging System:** Automatically captures and logs all standard output and errors (stdout/stderr) directly to `/var/log/grub-fixer.log`. If a chroot command fails, you now have a complete forensic trail for troubleshooting.
* **Fail-Fast Root Validation:** Instantly halts execution with a clean error message if the script is not initiated with `sudo` (checks `$EUID`), preventing messy, partial executions.

## 💎 Features from V7 (The Rescue Update)
* **Custom Volume Support:** Dynamically mount additional partitions (e.g., `/home`, `/var`, `/opt`) during the repair process.
* **Flexible Mounting:** Uses Bash arrays to handle multiple custom mount points with automatic directory creation inside `/mnt`.
* **Universal Chroot Prep:** Prepares a comprehensive environment, making it useful for general system recovery beyond just GRUB.

## 🧠 Core Features (V6 & Below)
* **Intelligent Auto-Detection:** Scans partitions using `lsblk` and `awk` to suggest the most likely **Root (/)**. Detects file systems (`ext4`, `btrfs`, `xfs`) without mounting, ensuring a lightning-fast pre-scan.
* **UX Proposal Flow:** Presents a "Proposal" box. Press **'y'** to proceed instantly or **'n'** to enter manual fallback mode.
* **VM & NVRAM Rescue:** Uses the `--removable` flag to guarantee booting on Virtual Machines and stubborn UEFI firmware that drop NVRAM variables.
* **Pipeline Ready:** Redirected `read` commands to `/dev/tty`, making it 100% compatible with `curl | bash` pipelines.
* **Safety & Cleanup:** Forced `set -e` for immediate halt on errors and automatic `umount -R` cleanup before and after execution to prevent mount conflicts.

---

## 📋 Requirements
* **Environment:** Live Linux ISO/USB (Arch, Ubuntu, Fedora, etc.).
* **Architecture:** Target system must be UEFI (`x86_64-efi`).
* **Privileges:** Sudo/Root access required.

## 🛠️ Planned for Future Updates
* **BIOS (Legacy) Support.**
* **LUKS (Encryption) & LVM Support.**
* **Full `fstab` Parsing:** For automatic detection and mounting of complex `/boot` and subvolume setups.

## ⚠️ Disclaimer
This tool is currently intended for **UEFI** systems. While V8 introduces robust safety checks, always verify the auto-detected partitions before confirming the repair process.

---
