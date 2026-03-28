# 🛠️ GRUB Fixer (V20 - The "Health Check & Auto-Dependency Resolver" Update)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on **UEFI (64/32-bit)** and **Legacy BIOS** Linux systems. **V20** pushes the script to the ultimate level of proactive recovery by automatically detecting and installing missing bootloader dependencies inside the broken system, complete with DNS resolution tunneling. This builds upon the **Universal RedHat/Fedora Support** (V19), **Deep Scan Engine**, and **Zero-Interaction** features of previous versions.

## 🚀 Usage

Run the "Ultimate Rescue Weapon" directly from your terminal:

### Option 1: Quick One-Liner (Interactive Mode)
The classic, smart, and unified interactive experience:
```bash
curl -sL [https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh](https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh) | sudo bash
```

### Option 2: Fully Automated (Zero-Interaction Mode) 💥
Skip all questions and let the script fix GRUB silently based on auto-detection (perfect for Live USBs):
```bash
curl -sL [https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh](https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh) | sudo bash -s -- -env l -auto
```

### Option 3: Manual Download
```bash
curl -O [https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh](https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh)
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh [FLAGS]
```

---

## 🩺 The Health Check Update (V20)

* **Smart Dependency Resolution:** Automatically detects if crucial packages (`grub`, `grub2`, `os-prober`, `efibootmgr`) are missing inside the target broken system (Chroot or In-Situ).
* **Multi-Package Manager Support:** Dynamically utilizes `pacman`, `apt-get`, `dnf`, or `zypper` to seamlessly install missing dependencies on the fly.
* **DNS Tunneling (`resolv.conf`):** Automatically copies the live host's `/etc/resolv.conf` into the chroot, ensuring the package managers have full internet access to download required fixes.

---

## 🌐 The Universal Update (V19)

* **RedHat/Fedora Family Support:** Full compatibility with Fedora, RHEL, CentOS, Rocky, and AlmaLinux.
* **Dynamic Command Routing:** Automatically reads `/etc/os-release` to switch between standard `grub-install` / `grub-mkconfig` and the RedHat-specific `grub2-install` / `grub2-mkconfig`.
* **Smart Pathing:** Intelligently manages configuration paths, dynamically creating and writing to `/boot/grub2/grub.cfg` or `/boot/grub/grub.cfg` as required by the host OS.

---

## 🚩 V18 CLI Flags Reference

V18 introduces Command-Line Arguments to bypass prompts and enable headless automation:

* **`-env l` or `-env live`**: Force the script to assume a **Live Environment** (USB/ISO).
* **`-env h` or `-env host`**: Force the script to assume a **Real Machine / Host** environment.
* **`-auto`**: The "Ultimate Mode" flag. Bypasses all confirmation prompts `(y/n)`, automatically assumes default mount points (like `/boot` for EFI), and executes the repair instantly.
* **`--version` or `-v`**: Print the current version and exit.

---

## ✨ The Intelligence Update (V17)

* **Kernel Cmdline Environment Detection:** The script reads `/proc/cmdline` to differentiate between a **Live ISO** (Archiso, Casper, Miso, etc.) and a **Real Machine** installation with 100% accuracy.
* **Deep Scan Engine:** Before asking a single question, a stealthy background scan temporarily mounts partitions to find your `/etc/fstab`, mapping your entire system layout (Root, Boot, EFI, and Btrfs subvolumes).
* **Unified One-Click Confirmation:** No more "death by a thousand questions." The script presents the detected layout in a clean summary and asks for a single confirmation.
* **Automatic `efivarfs` Repair:** Enhanced In-Situ logic to automatically mount `efivarfs` if the rescue environment (like Super GRUB2 Disk) fails to do so.

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

* **OS Families:** Arch Linux, Debian/Ubuntu, RedHat/Fedora, SUSE, and derivatives.
* **Architecture:** x86_64 or i386.
* **Platform:** UEFI (any bitness) or Legacy BIOS.
* **Filesystems:** Ext4, Btrfs (including subvolumes), XFS.
* **Privileges:** Sudo/Root access required.

## ⚠️ Disclaimer

While V20 is designed to be the safest and smartest version yet, repairing bootloaders involves critical system files. Always review the **Deep Scan** summary before confirming the repair, especially on complex multi-boot or encrypted setups.

---

**Developed with by [ahmed-x86](https://github.com/ahmed-x86)**
*Arch Linux Power User | Open Source Enthusiast*
