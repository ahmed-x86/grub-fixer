
# GRUB Fixer (V4)

An automated, failsafe Bash script designed to repair the GRUB bootloader on UEFI Linux systems via a live chroot environment. This tool automates the tedious process of mounting, binding system directories, and reinstalling GRUB.

## 🚀 Usage

Run the following command directly from your terminal in any Live Linux environment (Arch, EndeavourOS, etc.):

```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/refs/heads/main/grub-fixer.sh | bash
```

## ✨ New in V4
* **Safety First:** Implemented `set -e` to stop execution immediately if any command fails, preventing system damage.
* **Automatic Cleanup:** Detects and unmounts any existing processes on `/mnt` before starting to avoid conflicts.
* **Improved Validation:** Forces Root partition input and verifies partition existence in `/dev/` before proceeding.
* **Smart OS Detection:** Automatically detects the distribution name from `/etc/os-release` to set the correct Bootloader ID.
* **Zero-Intervention Chroot:** Executes all repair commands automatically inside the chroot environment using EOF blocks.

## 🛠 Features
* **Interactive Selection:** Guided selection for Root, Boot, and EFI partitions.
* **System Integrity:** Automated bind mounts for `/dev`, `/proc`, `/sys`, and `/run`.
* **Full Repair:** Handles both `grub-install` and `grub-mkconfig` in one go.
* **Clean Exit:** Automatically unmounts all filesystems recursively after a successful repair.

## 📋 Requirements
* **Environment:** Booted into a Live Linux ISO/USB.
* **Architecture:** Target system must be UEFI (`x86_64-efi`).
* **Privileges:** Sudo/Root access required.
* **Network:** Active internet connection to fetch the script.

## ⚠️ Disclaimer
Currently supports **UEFI (x86_64-efi)** only. Support for BIOS (Legacy), LUKS (Encryption), and LVM is planned for future releases.

