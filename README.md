# 🛠️ GRUB Fixer (V16 - Ultimate Automation, Legacy BIOS, OS Prober, Universal UEFI & In-Situ Repair)

An automated, bulletproof Bash script designed to repair the GRUB bootloader on both **UEFI and Legacy BIOS** Linux systems. **V16** transforms the script into a true "Universal Rescue Weapon," bringing **In-Situ (Local) Repair** capabilities, **Dynamic 32-bit/64-bit UEFI Detection**, a dynamic execution timer with gamer-style human responses, intelligent dual-boot detection (OS Prober), and the powerful **Zero-Interaction "Pro Mode"** that parses `/etc/fstab` to map and mount complex layouts (like Btrfs subvolumes) in seconds.

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

## ✨ New in V16 (The In-Situ Update)
* **In-Situ (Local) Mode Detection:** The script now intelligently detects if it's being run directly from your installed OS (e.g., booted via Super GRUB2 Disk or rEFInd) rather than a Live USB. It safely bypasses the complex chroot environment and repairs GRUB locally in seconds, automatically handling unmounted EFI variables (`efivarfs`) and boot partitions.

## ⚙️ Key Additions in V15, V14, V13 & V12
* **Dynamic UEFI 32-bit Detection (V15):** The script acts as a flawless Universal Bootloader Rescue tool. It intelligently reads `/sys/firmware/efi/fw_platform_size` to detect rare 32-bit UEFI architectures (often found in older devices) and automatically switches the GRUB target to `i386-efi`, while keeping `x86_64-efi` as the standard for modern 64-bit machines.
* **Dynamic Execution Timer (V14):** The script calculates the total execution time and delivers gamer-style, human-like status messages based on how fast the repair was completed (e.g., *"Wait, did I just fix that?! You didn't even get to sip your coffee! ☕😂🏃‍♂️"*).
* **OS Prober Integration (V13):** Solves the issue where Windows or other Linux distros disappear from the GRUB menu after a repair. It automatically modifies `/etc/default/grub` to enable `GRUB_DISABLE_OS_PROBER=false`, ensuring all installed operating systems are detected.
* **Legacy BIOS (`i386-pc`) Support (V12):** Automatically detects if your system lacks an EFI partition and dynamically switches to Legacy mode.
* **Smart Target Disk Extraction (V12):** In Legacy BIOS mode, uses `lsblk -no PKNAME` to intelligently extract the parent disk from your root partition (e.g., `/dev/sda`), ensuring flawless GRUB installation on older machines.

## 🧠 Core Features (From V11 & V10)
* **Zero-Interaction FSTAB Parsing (Tier 1):** Automatically scans devices to locate and parse your system's `/etc/fstab`. It resolves `UUID` and `PARTUUID` tags instantly, mapping out your exact system layout (Root, Boot, EFI, and Btrfs subvolumes) without manual input.
* **3-Tier Fallback System:** If `fstab` is missing, encrypted, or rejected, the script gracefully falls back to Smart Auto-Detection (Tier 2), and finally to fully Manual Input (Tier 3), guaranteeing a crash-free experience.
* **Bulletproof Btrfs Loop:** In manual/fallback mode, an interactive loop ensures required subvolumes (e.g., `@`, `@home`, `@log`) are mounted in the correct hierarchy with strict input validation.
* **Dynamic EFI Mount Logic:** Solves the common "missing kernel" trap by automatically verifying and applying the correct EFI mount path (`/boot` vs `/boot/efi`), which is critical for **Archinstall** and **CachyOS** setups.
* **VM & NVRAM Rescue:** Uses the `--removable` flag to guarantee booting on Virtual Machines (QEMU/KVM) and stubborn UEFI firmware that drop NVRAM variables.

## 💎 Advanced Rescue Tech
* **Blackbox Logging System:** Automatically captures and logs all standard output and errors directly to `/var/log/grub-fixer.log` for a complete forensic troubleshooting trail.
* **Pipeline Ready:** Fully compatible with `curl | bash` pipelines thanks to TTY redirection for all user inputs.
* **OS Detection:** Automatically sources `/etc/os-release` from the target system to set the correct Bootloader ID.
* **Safety & Cleanup:** Forced `set -e` for immediate halt on errors and automatic `umount -R` cleanup to prevent mount conflicts.

---

## 📋 Requirements
* **Environment:** Live Linux ISO/USB (Arch, CachyOS, Fedora, Ubuntu, etc.) **OR** directly from your installed OS if booted via a rescue tool.
* **Architecture:** Target system must be UEFI (`x86_64-efi` or `i386-efi`) OR Legacy BIOS (`i386-pc`).
* **Privileges:** Sudo/Root access required.

## ⚠️ Disclaimer
While highly automated, GRUB repair touches critical system files. Always verify the auto-detected partitions, `fstab` layout, and subvolumes before confirming the repair process, especially on dual-boot systems.
