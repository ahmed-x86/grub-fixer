# 🛠️ GRUB Fixer (V11 - Ultimate Automation & FSTAB Edition)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on UEFI Linux systems. **V11** is a massive leap forward, introducing a **Zero-Interaction "Pro Mode"** that parses `/etc/fstab` to map and mount complex layouts (like Btrfs subvolumes) in seconds, turning a 30-minute manual recovery into a 5-second automated task.

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

## ✨ New in V11 (The Automation Update)
* **Zero-Interaction FSTAB Parsing (Tier 1):** Automatically scans devices to locate and parse your system's `/etc/fstab`. It resolves `UUID` and `PARTUUID` tags instantly, mapping out your exact system layout (Root, Boot, EFI, and Btrfs subvolumes) without manual input.
* **3-Tier Fallback System:** If `fstab` is missing, encrypted, or rejected, the script gracefully falls back to V10's Smart Auto-Detection (Tier 2), and finally to fully Manual Input (Tier 3), guaranteeing a crash-free experience.
* **5-Second Rescue:** Bypasses tedious manual typing. With a single `y` confirmation, the script dynamically mounts all partitions and subvolumes, chroots, and fixes GRUB in under 5 seconds.

## 🛡️ Features from V10 & V9
* **Dynamic EFI Mount Logic:** Solves the common "missing kernel" trap by automatically verifying and applying the correct EFI mount path (`/boot` vs `/boot/efi`), which is especially critical for **Archinstall** and **CachyOS** setups.
* **Bulletproof Btrfs Loop:** In manual/fallback mode, an interactive loop ensures required subvolumes (e.g., `@`, `@home`, `@log`) are mounted in the correct hierarchy with strict input validation.
* **Smart Mount Routing:** Automatically translates standard mount points to their chroot equivalents (e.g., inputting `/` correctly targets `/mnt`).
* **VM & NVRAM Rescue:** Uses the `--removable` flag to guarantee booting on Virtual Machines (QEMU/KVM) and stubborn UEFI firmware that drop NVRAM variables.

## 💎 Core Rescue Tech
* **Blackbox Logging System:** Automatically captures and logs all standard output and errors directly to `/var/log/grub-fixer.log` for a complete forensic troubleshooting trail.
* **Pipeline Ready:** Fully compatible with `curl | bash` pipelines thanks to TTY redirection for all user inputs.
* **OS Detection:** Automatically sources `/etc/os-release` from the target system to set the correct Bootloader ID.
* **Safety & Cleanup:** Forced `set -e` for immediate halt on errors and automatic `umount -R` cleanup to prevent mount conflicts.

---

## 📋 Requirements
* **Environment:** Live Linux ISO/USB (Arch, CachyOS, Fedora, Ubuntu, etc.).
* **Architecture:** Target system must be UEFI (`x86_64-efi`).
* **Privileges:** Sudo/Root access required.




## ⚠️ Disclaimer
This tool is currently intended for **UEFI** systems. Always verify the auto-detected partitions, `fstab` layout, and subvolumes before confirming the repair process.