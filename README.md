# 🛠️ GRUB Fixer (V17 - The "Deep Scan" & Unified UX Update)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on **UEFI (64/32-bit)** and **Legacy BIOS** Linux systems. **V17** pushes the boundaries of automation with **Kernel Command Line Detection**, a proactive **Deep Scan Engine**, and a **Unified One-Click Confirmation** system that eliminates decision fatigue during system recovery.

## 🚀 Usage

Run the "Ultimate Rescue Weapon" with a single command:

### Option 1: Quick One-Liner (Recommended)

```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh | sudo bash
```

### Option 2: Manual Download

```bash
curl -O https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh
```

-----

## ✨ New in V17 (The Intelligence Update)

  * **Kernel Cmdline Environment Detection:** The script now reads `/proc/cmdline` to differentiate between a **Live ISO** (Archiso, Casper, Miso, etc.) and a **Real Machine** installation with 100% accuracy.
  * **Deep Scan Engine:** Before asking a single question, V17 performs a stealthy background scan. It temporarily mounts partitions to find your `/etc/fstab`, mapping your entire system layout (Root, Boot, EFI, and Btrfs subvolumes) before you even hit "Enter."
  * **Unified One-Click Confirmation:** No more "death by a thousand questions." V17 presents the detected layout and environment in a clean summary and asks for a single confirmation to proceed.
  * **Automatic `efivarfs` Repair:** Enhanced In-Situ logic to automatically mount `efivarfs` if the rescue environment (like Super GRUB2 Disk) fails to do so.

## ⚙️ Evolution Registry (V16 - V12)

  * **In-Situ (Local) Repair (V16):** Allows repairing GRUB directly from the installed OS without a Live USB/Chroot environment.
  * **Universal UEFI Support (V15):** Detects 32-bit vs 64-bit UEFI architectures (`fw_platform_size`) and switches between `i386-efi` and `x86_64-efi` automatically.
  * **Gamer-Style Execution Timer (V14):** Provides human-like feedback based on speed (e.g., *"Wait, did I just fix that?\! You didn't even get to sip your coffee\! ☕"*).
  * **OS Prober Integration (V13):** Automatically enables `GRUB_DISABLE_OS_PROBER=false` to ensure Windows and other distros appear in the menu.
  * **Legacy BIOS support (V12):** Full support for `i386-pc` with intelligent parent disk extraction (e.g., detecting `/dev/sda` from `/dev/sda1`).

## 🧠 Core "Pro" Features

  * **3-Tier Fallback System:**
    1.  **Tier 1:** Zero-Interaction `fstab` Parsing.
    2.  **Tier 2:** Smart Auto-Detection (lsblk & blkid).
    3.  **Tier 3:** Manual Interactive Input.
  * **Btrfs Mastery:** Automatic handling of subvolumes (like `@`, `@home`, `@log`) with a bulletproof validation loop.
  * **NVRAM & VM Rescue:** Uses the `--removable` flag to ensure compatibility with stubborn UEFI firmware and Virtual Machines (QEMU/KVM).
  * **Blackbox Logging:** Every action is logged to `/var/log/grub-fixer.log` for post-repair forensics.

-----

## 📋 Requirements & Compatibility

  * **Architecture:** x86\_64 or i386.
  * **Platform:** UEFI (any bitness) or Legacy BIOS.
  * **Filesystems:** Ext4, Btrfs (including subvolumes), XFS.
  * **Privileges:** Sudo/Root access required.

## ⚠️ Disclaimer

V17 is designed to be the safest version yet, but repairing bootloaders involves critical system files. Always review the **Deep Scan** summary before confirming the repair, especially on complex multi-boot or encrypted setups.

-----

**Developed with  by [ahmed-x86](https://www.google.com/search?q=https://github.com/ahmed-x86)**
*Arch Linux Power User | Open Source Enthusiast*

-----
