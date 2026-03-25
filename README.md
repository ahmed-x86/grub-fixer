# GRUB Fixer (V5)

An automated, failsafe Bash script designed to repair the GRUB bootloader on UEFI Linux systems via a live chroot environment. This tool automates the tedious process of mounting, binding system directories, and reinstalling GRUB.

## 🚀 Usage

Run the following commands directly from your terminal in any Live Linux environment (Arch, EndeavourOS, Ubuntu, Fedora, etc.):

```bash
curl -O https://raw.githubusercontent.com/ahmed-x86/grub-fixer/refs/heads/main/grub-fixer.sh
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh
```

## ✨ New in V5 (Bulletproof Edition)
* **VM & NVRAM Rescue:** Added the `--removable` flag to `grub-install` to guarantee successful booting on Virtual Machines and stubborn UEFI firmware that drop NVRAM entries.
* **Input Collision Prevention:** `read` commands now strictly fetch input from `/dev/tty`, eliminating terminal buffer conflicts and pipeline issues.

## 🛠 Core Features
* **Safety First:** Implemented `set -e` to stop execution immediately if any command fails, preventing system damage.
* **Automatic Cleanup:** Detects and unmounts any existing processes on `/mnt` before starting to avoid conflicts.
* **Improved Validation:** Forces Root partition input and strictly verifies partition existence in `/dev/` before proceeding.
* **Smart OS Detection:** Automatically detects the distribution name from `/etc/os-release` to set the correct Bootloader ID.
* **Zero-Intervention Chroot:** Executes all repair commands (`grub-install` and `grub-mkconfig`) automatically inside the chroot environment using EOF blocks.
* **Clean Exit:** Automatically unmounts all filesystems recursively after a successful repair.

## 📋 Requirements
* **Environment:** Booted into a Live Linux ISO/USB.
* **Architecture:** Target system must be UEFI (`x86_64-efi`).
* **Privileges:** Sudo/Root access required.
* **Network:** Active internet connection to fetch the script.

## ⚠️ Disclaimer
Currently supports **UEFI (x86_64-efi)** only. Support for BIOS (Legacy), LUKS (Encryption), and LVM is planned for future releases.