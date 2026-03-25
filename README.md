# GRUB Fixer

An automated Bash script to repair the GRUB bootloader on UEFI Linux systems via a live chroot environment.

## Usage

Run the following command directly from your terminal in a Live Linux environment:

```bash
curl -sL https://raw.githubusercontent.com/ahmed-x86/grub-fixer/refs/heads/main/grub-fixer.sh | bash
```

## Features

* Interactive partition selection (Root, Boot, EFI).
* Automated bind mounts (`/dev`, `/proc`, `/sys`, `/run`).
* Automated OS detection inside the chroot environment.
* Seamless GRUB reinstallation and configuration (`grub.cfg`) generation.
* Automatic cleanup and unmounting upon completion.

## Requirements

* Booted into a Live Linux ISO/USB.
* Active internet connection (to fetch the script).
* Sudo privileges.
* Target system must be UEFI (`x86_64-efi`).