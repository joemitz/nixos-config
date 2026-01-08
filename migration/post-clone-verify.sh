#!/usr/bin/env bash
# Post-clone verification script
# Run this after booting from the new cloned disk

echo "=== Disk Labels ==="
lsblk -o NAME,SIZE,LABEL,MOUNTPOINT

echo -e "\n=== Btrfs Subvolumes ==="
sudo btrfs subvolume list /

echo -e "\n=== Filesystem Usage ==="
df -h / /nix /persist-root /persist-dotfiles /persist-userfiles

echo -e "\n=== Btrfs Filesystem Size ==="
sudo btrfs filesystem show /

echo -e "\n=== EFI Boot Entries ==="
efibootmgr

echo -e "\n=== Mounted Filesystems ==="
findmnt / /boot /nix /persist-root /persist-dotfiles /persist-userfiles
