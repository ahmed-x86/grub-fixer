# GRUB Fixer - Changelog
Author: ahmed-x86

* **V1:** Basic manual-like chroot logic for GRUB repair.
* **V2:** Added input validation (checks if partition exists) and loops for user input.
* **V3:** Added /mnt cleanup (umount -R) before starting to prevent mount conflicts.
* **V4:** Added 'set -e' for safety, forced Root partition input, OS detection.
* **V5:** Added '--removable' to fix VM/NVRAM issues, and TTY Pipeline support.
* **V6:** Added Auto-Detection using lsblk FSTYPE without mounting.
* **V7:** Added dynamic support for mounting custom volumes (e.g., /home, /var).
* **V8:** Added Root Validation, System Logging, and Smart EFI Detection.
* **V9:** Added dynamic Btrfs subvolumes support with smart routing.
* **V10:** Bulletproof Btrfs loop (forced y/n), fixed Archinstall /boot vs /boot/efi trap.
* **V11:** Zero-Interaction Mode (fstab parser), 3-Tier Fallback System.
* **V12:** Added Legacy BIOS (i386-pc) support, auto-detection, and Target Disk extraction.
* **V13:** Added OS Prober support to automatically detect dual-boot systems (e.g., Windows).
* **V14:** Added Execution Timer with dynamic human-like status messages.
* **V15:** Added Universal UEFI Support (32-bit/i386-efi) with dynamic bitness detection.
* **V16:** Added In-Situ (Local) Mode to repair GRUB directly from the running system without Live USB/chroot.
* **V17:** Added Kernel cmdline detection for Live vs Real, and unified One-Click Confirmation prompt.
* **V18:** Added CLI Flags (--version, -env l/h, -auto) for complete Zero-Interaction Automation.
* **V19:** Added universal support for RedHat/Fedora/CentOS family (dynamic grub2 commands & paths).
* **V20:** Chroot Health Check - Auto-detects and installs missing GRUB/EFI packages with DNS resolv support.
* **V21:** LUKS & LVM Encryption Support - Auto-detects, unlocks (visible password), and configures GRUB_ENABLE_CRYPTODISK.
* **V22:** Secure Boot & Shim Integration - Auto-detects Secure Boot, handles shim-signed, and MOK Enrollment (OTP 1234).
* **V23:** Security Hardening & Bug Fixes:
     - [SEC-1] LUKS password input is now hidden (read -s) to prevent shoulder-surfing.
     - [SEC-2] MOK OTP is now randomly generated (openssl) instead of hardcoded "1234".
     - [SEC-3] /etc/default/grub is backed up before any modification.
     - [BUG-1] Fixed clash with bash reserved variable $SECONDS -> renamed to $SECS_DISPLAY.
     - [BUG-2] efi_ans is now initialized before Tier 1 (PRO_MODE) to prevent unbound variable errors.
     - [BUG-3] source /mnt/etc/os-release replaced with targeted grep to avoid environment pollution.
* **V24:** The "Backend API" Update:
     - Added JSON Endpoints (--sys-info, --json-scan) for GUI/TUI integration.
     - Added Explicit Partition Mapping (--map-std, --map-btrfs) to bypass all prompts.
     - Fixed mkdir -p bug during fstab JSON extraction.
     - Script can now operate purely as a backend worker for graphical frontends.
* **V25:** The Polishing Update:
     - [BUG-1] Fixed Legacy BIOS + Btrfs crash on VMs (VirtIO) by adding Regex fallback for Target Disk extraction.
     - [BUG-2] Fixed empty subvolume mount crash in fstab parser (Tier 1).
* **V26:** The Modular Update:
     - Completely refactored the monolith script into a modular architecture.
     - Modules (api, ui, core_scan, crypto, secureboot) are loaded on-the-fly.
     - Supports both local execution (git clone) and remote execution (curl | bash).
* **V27:** The Bulletproof Update:
     - [SEC-4] Implemented strict `trap` engine to automatically unmount and clean up system on `EXIT`, `ERR`, or `INT` (`Ctrl+C`), preventing disk locks.
     - [SEC-5] Download integrity verification added; `curl` now downloads modules to `.tmp` files first, preventing partial code execution on network drops.
     - Global `ask_yes_no` function replaces fragile `read` prompts across all modules, ensuring input validation (y/n) even through CLI pipes (`</dev/tty`).
     - Intelligent `/var/log` fallback to `/tmp` to support read-only Live USB environments.