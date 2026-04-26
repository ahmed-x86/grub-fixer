# 🛠️ GRUB Fixer (V26 - The "Modular" Update)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on **UEFI (64/32-bit)** and **Legacy BIOS** Linux systems. **V26** completely refactors the script into a professional modular architecture with a smart on-the-fly loader. This builds upon the **VM Polishing** (V25), **Backend API** (V24), **Security Hardening** (V23), **Secure Boot & Shim Support** (V22), **LUKS Encryption** (V21), and **Chroot Health Checks** (V20) of previous versions.

## 🚀 Usage

Run the "Ultimate Rescue Weapon" directly from your terminal:

### Option 1: Quick One-Liner (Interactive Mode)
The classic, smart, and unified interactive experience. (Powered by the V26 Smart Loader to fetch modules on-the-fly):
```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh | sudo bash
```

### Option 2: Fully Automated (Zero-Interaction Mode) 💥
Skip all questions and let the script fix GRUB silently based on auto-detection (perfect for Live USBs):
```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/main/grub-fixer.sh | sudo bash -s -- -env l -auto
```

### Option 3: Manual Download (Local Execution)
Clone the repo to automatically use the local modules:
```bash
git clone https://github.com/ahmed-x86/grub-fixer.git
cd grub-fixer
chmod +x grub-fixer.sh
sudo ./grub-fixer.sh [FLAGS]
```

---

## 🧩 The Modular Update (V26)

* **Architectural Overhaul:** The massive 1200+ line monolith script has been completely deconstructed into a sleek, modular engine. Core functionalities are now isolated into dedicated, easy-to-maintain modules (`api.sh`, `ui.sh`, `crypto.sh`, `core_scan.sh`, `secureboot.sh`).
* **Smart Module Loader:** Intelligently detects the execution context. If run locally (via `git clone`), it sources the adjacent files seamlessly. If executed via the `curl | bash` one-liner, it downloads the necessary modules on-the-fly to a temporary directory, ensuring the tool never breaks in isolated environments.
* **Developer Ready:** This architecture paves the exact path needed for the upcoming Python/GTK GUI integration, making the codebase drastically easier to debug and expand.

---

## ✨ The Polishing Update (V25)

* **Legacy BIOS VM Fix (VirtIO):** Added an intelligent Regex fallback for Target Disk extraction. This ensures that `lsblk` topology failures on virtual machines (like QEMU/KVM VirtIO or NVMe drives) no longer cause the script to crash during Legacy BIOS repairs.
* **Btrfs Subvolume Hardening:** Fixed a critical bug in the Tier 1 `fstab` parser where empty subvolume definitions caused the mount command to fail, ensuring bulletproof parsing of default Btrfs root setups.

---

## 🔌 The Backend API Update (V24)

* **JSON Endpoints for GUIs:** Designed to be the brain behind graphical interfaces. Passing `--sys-info` returns live system state (environment, firmware, battery), and `--json-scan` silently parses `fstab` to output a clean JSON array of the detected partition layout.
* **Explicit Execution Mapping:** Bypasses all interactive logic and deep scans when explicitly instructed by a frontend GUI.
* **Standard Mapping (`--map-std`):** Accepts structured payloads for Ext4/XFS layouts (e.g., `vda1:efi:/boot/efi vda2:root:/ vda3:ext:/mnt/data`).
* **Btrfs Subvolume Mapping (`--map-btrfs`):** Handles complex Btrfs layouts seamlessly (e.g., `nvme0n1p1:efi:/boot nvme0n1p2:root:/=@,/home=@home`).
* **Headless Worker:** Operates flawlessly in the background, executing precise mounts, LUKS unlocks, and GRUB repairs based purely on GUI-provided data strings.

---

## 🔒 The Security Hardening Update (V23)

* **Anti-Shoulder Surfing:** LUKS password input is now completely hidden (`read -s`) during the early decryption phase to protect your credentials in public or shared environments.
* **Dynamic MOK OTP Generation:** Replaced the hardcoded Secure Boot password with a dynamically generated, 12-character random One-Time Password using `openssl`.
* **Failsafe Config Backups:** Automatically creates a timestamped backup of `/etc/default/grub` before making any modifications to the system's boot configuration.
* **Environment Isolation:** Uses targeted `grep` parsing instead of sourcing `/mnt/etc/os-release` to prevent host environment variable pollution during Chroot.
* **Bash Integrity:** Resolved variable naming conflicts (`$SECONDS`) and unbound variable errors during automated Tier 1 execution.

---

## 🛡️ The Secure Boot Update (V22)

* **Smart State Detection:** Utilizes `mokutil --sb-state` to check if Secure Boot is enforced before attempting any GRUB installation.
* **Dynamic Shim Routing:** Automatically forces the `--uefi-secure-boot` flag on Debian/Ubuntu systems to utilize Microsoft-signed `shim` binaries instead of standard GRUB.
* **Arch Linux `sbctl` Integration:** Detects if Arch Linux users are utilizing custom Secure Boot keys and attempts to automatically sign the new GRUB binary using `sbctl sign`.
* **Automated MOK Enrollment:** Imports the `MOK.der` key silently and automatically feeds the dynamically generated OTP to the system, leaving the user with simple, clear instructions for their next reboot to authorize the bootloader permanently.

---

## 🔐 The LUKS Encryption Update (V21)

* **Early LUKS Detection:** Scans for `crypto_LUKS` partitions *before* the Deep Scan Engine starts, preventing scan failures on encrypted drives.
* **Interactive Smart Decryption:** Prompts to unlock partitions using `cryptsetup` to prevent lockouts.
* **LVM Auto-Activation:** Automatically runs `vgchange -ay` to expose hidden Logical Volumes inside unlocked LUKS containers.
* **Auto-Cryptodisk Injection:** Automatically appends `GRUB_ENABLE_CRYPTODISK=y` to `/etc/default/grub` ensuring the repaired system actually prompts for a password on boot.
* **Secure Relocking:** Safely executes `luksClose` and deactivates volume groups after a successful repair to maintain data security.

---

## 🩺 The Health Check Update (V20)

* **Smart Dependency Resolution:** Automatically detects if crucial packages (`grub`, `grub2`, `os-prober`, `efibootmgr`, `cryptsetup`, `mokutil`) are missing inside the target broken system (Chroot or In-Situ).
* **Multi-Package Manager Support:** Dynamically utilizes `pacman`, `apt-get`, `dnf`, or `zypper` to seamlessly install missing dependencies on the fly.
* **DNS Tunneling (`resolv.conf`):** Automatically copies the live host's `/etc/resolv.conf` into the chroot, ensuring the package managers have full internet access to download required fixes.

---

## 🌐 The Universal Update (V19)

* **RedHat/Fedora Family Support:** Full compatibility with Fedora, RHEL, CentOS, Rocky, and AlmaLinux.
* **Dynamic Command Routing:** Automatically reads `/etc/os-release` to switch between standard `grub-install` / `grub-mkconfig` and the RedHat-specific `grub2-install` / `grub2-mkconfig`.
* **Smart Pathing:** Intelligently manages configuration paths, dynamically creating and writing to `/boot/grub2/grub.cfg` or `/boot/grub/grub.cfg` as required by the host OS.

---

## 🚩 CLI Flags & API Reference

Bypass prompts, enable headless automation, or integrate with graphical frontends:

* **`--sys-info`**: Return basic system information (environment type, firmware, battery) as JSON.
* **`--json-scan`**: Perform a stealth scan and output the detected partition/fstab layout as a JSON array.
* **`--map-std "<mapping>"`**: Provide an explicit partition layout for standard filesystems (e.g., `--map-std "sda1:efi:/boot sda2:root:/"`).
* **`--map-btrfs "<mapping>"`**: Provide an explicit partition layout for Btrfs setups with subvolumes.
* **`-env l` or `-env live`**: Force the script to assume a **Live Environment** (USB/ISO).
* **`-env h` or `-env host`**: Force the script to assume a **Real Machine / Host** environment.
* **`-auto`**: The "Ultimate Mode" flag. Bypasses all confirmation prompts `(y/n)`, automatically assumes default mount points (like `/boot` for EFI), and executes the repair instantly.
* **`--version` or `-v`**: Print the current version and exit.

---

## ⚙️ Evolution Registry (V12 - V17)

* **Kernel Cmdline Detection (V17):** Reads `/proc/cmdline` to differentiate between Live ISO and Real Machine with 100% accuracy.
* **In-Situ (Local) Repair (V16):** Allows repairing GRUB directly from the installed OS without a Live USB/Chroot environment.
* **Universal UEFI Support (V15):** Detects 32-bit vs 64-bit UEFI architectures (`fw_platform_size`) and switches between `i386-efi` and `x86_64-efi` automatically.
* **Gamer-Style Execution Timer (V14):** Provides human-like feedback based on speed (e.g., *"Wait, did I just fix that?! You didn't even get to sip your coffee! ☕"*).
* **OS Prober Integration (V13):** Automatically enables `GRUB_DISABLE_OS_PROBER=false` to ensure Windows and other distros appear in the menu.
* **Legacy BIOS support (V12):** Full support for `i386-pc` with intelligent parent disk extraction (handles nested LUKS/LVM).

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
* **Filesystems:** Ext4, Btrfs (including subvolumes), XFS, LUKS, LVM2.
* **Privileges:** Sudo/Root access required.

## ⚠️ Disclaimer

While V26 is designed to be the safest, smartest, and cleanest version yet, repairing bootloaders involves critical system files. Always review the **Deep Scan** summary before confirming the repair, especially on complex multi-boot or encrypted setups.

---

**Developed with  by [ahmed-x86](https://github.com/ahmed-x86)**
*Arch Linux Power User | Open Source Enthusiast*
