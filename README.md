# 🛠️ GRUB Fixer (V7 - Rescue Suite Edition)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on UEFI Linux systems. **V7** evolves from a simple fixer into a full **Rescue Suite**, allowing you to dynamically mount custom partitions like `/home`, `/var`, or `/usr` for a perfect chroot environment.

## 🚀 Usage

You can choose between the quick one-liner or the manual download method depending on your environment.

### Option 1: Quick One-Liner (Recommended)
Run the script directly without downloading:
```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh | bash
```

### Option 2: Manual Download & Execute
If you prefer to have the file locally or the one-liner doesn't suit your environment:
```bash
curl -O https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh
```

---

## ✨ New in V7 (The Rescue Update)
* **Custom Volume Support:** Dynamically mount additional partitions (e.g., `/home`, `/var`, `/opt`) during the repair process.
* **Flexible Mounting:** Uses Bash arrays to handle multiple custom mount points with automatic directory creation inside `/mnt`.
* **Universal Chroot Prep:** Prepares a comprehensive environment, making it useful for general system recovery beyond just GRUB.

## 💎 Features from V6 (The Smart Update)
* **Smart Auto-Detection:** Scans partitions using `lsblk` and `awk` to suggest the most likely **Root (/)** and **EFI (/boot/efi)**.
* **UX Proposal Flow:** Presents a "Proposal" box. Press **'y'** to proceed instantly or **'n'** to enter manual mode.
* **Metadata Scanning:** Detects file systems (`ext4`, `btrfs`, `xfs`, `vfat`) without mounting, ensuring a fast pre-scan.

## 🛡️ Core Safety (Bulletproof Engine)
* **VM & NVRAM Rescue:** Uses the `--removable` flag to guarantee booting on Virtual Machines and stubborn UEFI firmware.
* **Pipeline Ready:** Redirected `read` commands to `/dev/tty`, making it 100% compatible with `curl | bash`.
* **Safety & Cleanup:** Forced `set -e` for immediate halt on errors and automatic `umount -R` cleanup before and after execution.

---

## 📋 Requirements
* **Environment:** Live Linux ISO/USB (Arch, Ubuntu, Fedora, etc.).
* **Architecture:** Target system must be UEFI (`x86_64-efi`).
* **Privileges:** Sudo/Root access required.

## 🛠️ Planned for Future
* **BIOS (Legacy) Support.**
* **LUKS (Encryption) & LVM Support.**
* **Full fstab Parsing:** For automatic detection of complex `/boot` setups.

## ⚠️ Disclaimer
This tool is intended for **UEFI** systems. Always verify the auto-detected partitions before confirming the repair process.

---

