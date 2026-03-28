# 🛠️ GRUB Fixer (V18 - The "Zero-Interaction" Automation Update)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on **UEFI (64/32-bit)** and **Legacy BIOS** Linux systems. **V18** takes system recovery to the absolute limit with **CLI Flags for fully automated, Zero-Interaction deployments**, building upon the proactive **Deep Scan Engine** and **Kernel Command Line Detection** introduced in V17. 

## 🚀 Usage

Run the "Ultimate Rescue Weapon" directly from your terminal:

### Option 1: Quick One-Liner (Interactive Mode)
The classic, smart, and unified interactive experience:
```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh | sudo bash
```

### Option 2: Fully Automated (Zero-Interaction Mode) 💥
Skip all questions and let the script fix GRUB silently based on auto-detection (perfect for Live USBs):
```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh | sudo bash -s -- -env l -auto
```

### Option 3: Manual Download
```bash
curl -O https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh [FLAGS]
```

---

## 🚩 V18 CLI Flags Reference

V18 introduces Command-Line Arguments to bypass prompts and enable headless automation:

* **`-env l` or `-env live`**: Force the script to assume a **Live Environment** (USB/ISO).
* **`-env h` or `-env host`**: Force the script to assume a **Real Machine / Host** environment.
* **`-auto`**: The "Ultimate Mode" flag. Bypasses all confirmation prompts `(y/n)`, automatically assumes default mount points (like `/boot` for EFI), and executes the repair instantly.
* **`--version` or `-v`**: Print the current version and exit.

---

## ✨ The Intelligence Update (V17 & V18)

* **Headless Automation (V18):** Pass flags directly via the pipeline to execute complex GRUB repairs without a single keystroke.
* **Kernel Cmdline Environment Detection (V17):** The script reads `/proc/cmdline` to differentiate between a **Live ISO** (Archiso, Casper, Miso, etc.) and a **Real Machine** installation with 100% accuracy.
* **Deep Scan Engine (V17):** Before asking a single question, a stealthy background scan temporarily mounts partitions to find your `/etc/fstab`, mapping your entire system layout (Root, Boot, EFI, and Btrfs subvolumes).
* **Unified One-Click Confirmation (V17):** No more "death by a thousand questions." The script presents the detected layout in a clean summary and asks for a single confirmation.
* **Automatic `efivarfs` Repair (V17):** Enhanced In-Situ logic to automatically mount `efivarfs` if the rescue environment (like Super GRUB2 Disk) fails to do so.

---

## ⚙️ Evolution Registry (V12 - V16)

* **In-Situ (Local) Repair (V16):** Allows repairing GRUB directly from the installed OS without a Live USB/Chroot environment.
* **Universal UEFI Support (V15):** Detects 32-bit vs 64-bit UEFI architectures (`fw_platform_size`) and switches between `i386-efi` and `x86_64-efi` automatically.
* **Gamer-Style Execution Timer (V14):** Provides human-like feedback based on speed (e.g., *"Wait, did I just fix that?! You didn't even get to sip your coffee! ☕"*).
* **OS Prober Integration (V13):** Automatically enables `GRUB_DISABLE_OS_PROBER=false` to ensure Windows and other distros appear in the menu.
* **Legacy BIOS support (V12):** Full support for `i386-pc` with intelligent parent disk extraction (e.g., detecting `/dev/sda` from `/dev/sda1`).

---

## 🧠 Core "Pro" Features

* **3-Tier Fallback System:**
    1.  **Tier 1:** Zero-Interaction `fstab` Parsing.
    2.  **Tier 2:** Smart Auto-Detection (`lsblk` & `blkid`).
    3.  **Tier 3:** Manual Interactive Input.
* **Btrfs Mastery:** Automatic handling of subvolumes (like `@`, `@home`, `@log`) with a bulletproof validation loop.
* **NVRAM & VM Rescue:** Uses the `--removable` flag to ensure compatibility with stubborn UEFI firmware and Virtual Machines (QEMU/KVM).
* **Blackbox Logging:** Every action is logged to `/var/log/grub-fixer.log` for post-repair forensics.

---

## 📋 Requirements & Compatibility

* **Architecture:** x86_64 or i386.
* **Platform:** UEFI (any bitness) or Legacy BIOS.
* **Filesystems:** Ext4, Btrfs (including subvolumes), XFS.
* **Privileges:** Sudo/Root access required.

## ⚠️ Disclaimer

While V18 is designed to be the safest and smartest version yet, repairing bootloaders involves critical system files. Always review the **Deep Scan** summary before confirming the repair, especially on complex multi-boot or encrypted setups.

---

**Developed with ❤️ by [ahmed-x86](https://github.com/ahmed-x86)**
*Arch Linux Power User | Open Source Enthusiast*
