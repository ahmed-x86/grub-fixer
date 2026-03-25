# 🛠️ GRUB Fixer (V10 - Ultimate Btrfs & Mount Routing Edition)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on UEFI Linux systems. **V10** is a major stability update that addresses specific installation quirks (like `archinstall`) and introduces a "Zero-Error" interactive flow for complex Btrfs layouts.

## 🚀 Usage

You can choose between the quick one-liner or the manual download method depending on your environment.

### Option 1: Quick One-Liner (Recommended)
Run the script directly without downloading:
```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh | sudo bash
```

### Option 2: Manual Download & Execute
If you prefer to have the file locally or want to audit the code before running:
```bash
curl -O https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh
```

---

## ✨ New in V10 (The Bulletproof Update)
* **Dynamic EFI Mount Logic:** Solves the common "missing kernel" trap by allowing users to choose the EFI mount path (`/boot` vs `/boot/efi`). This ensures `grub-mkconfig` always finds your `vmlinuz` images, especially on **Archinstall** setups.
* **Forced Validation Loop:** The Btrfs subvolume mounting process is now bulletproof. It forces a strict `y/n` check, preventing the script from skipping crucial partitions due to accidental keyboard input or typos.
* **Improved Auto-Detection:** Enhanced pre-scan logic to verify EFI partitions by looking for the actual `/EFI` directory structure before proposing it to the user.



## 🛡️ Features from V9 & V8
* **Dynamic Btrfs Subvolumes Support:** Interactive loop to mount required subvolumes (e.g., `@`, `@home`, `@log`, `@pkg`) in the correct hierarchy before chrooting.
* **Smart Mount Routing:** Automatically translates standard mount points to their chroot equivalents (e.g., inputting `/` correctly targets `/mnt`).
* **Blackbox Logging System:** Automatically captures and logs all standard output and errors directly to `/var/log/grub-fixer.log` for a complete forensic troubleshooting trail.
* **VM & NVRAM Rescue:** Uses the `--removable` flag to guarantee booting on Virtual Machines (QEMU/KVM) and stubborn UEFI firmware that drop NVRAM variables.

## 💎 Core Rescue Tech
* **Pipeline Ready:** Fully compatible with `curl | bash` pipelines thanks to TTY redirection for all user inputs.
* **OS Detection:** Automatically sources `/etc/os-release` from the target system to set the correct Bootloader ID.
* **Safety & Cleanup:** Forced `set -e` for immediate halt on errors and automatic `umount -R` cleanup to prevent mount conflicts.

---

## 📋 Requirements
* **Environment:** Live Linux ISO/USB (Arch, CachyOS, Fedora, etc.).
* **Architecture:** Target system must be UEFI (`x86_64-efi`).
* **Privileges:** Sudo/Root access required.

## 🛠️ Planned for V11 (The "Automation" Challenge)
* **Zero-Interaction Mode:** Automatic `fstab` parsing to detect and mount all partitions without a single prompt.
* **Kernel-Seeker:** Auto-detection of the kernel image location to set the EFI mount path without user input.
* **BIOS (Legacy) Support.**

## ⚠️ Disclaimer
This tool is currently intended for **UEFI** systems. Always verify the auto-detected partitions and subvolumes before confirming the repair process.

---