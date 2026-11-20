#!/usr/bin/env bash
# Boot a built ISO in a QEMU window (on Linux; on a Mac use UTM, see README).
#   scripts/run-qemu.sh              boot the live ISO
#   scripts/run-qemu.sh disk.img     also attach a disk to install onto
#                                    (created as 16 GB if it doesn't exist)
#   ARCH=arm64 scripts/run-qemu.sh   pick the ARM image
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${ARCH:-$(dpkg --print-architecture 2>/dev/null || echo amd64)}
ISO=$(ls "$HERE"/out/*-"$ARCH".iso 2>/dev/null | tail -1)
[ -n "$ISO" ] || { echo "no $ARCH ISO in out/ - run sudo ./build.sh first" >&2; exit 1; }

if [ "$ARCH" = arm64 ]; then
    FW=/usr/share/AAVMF/AAVMF_CODE.fd
    [ -e "$FW" ] || { echo "install qemu-efi-aarch64 first" >&2; exit 1; }
    args=(qemu-system-aarch64 -M virt -cpu max -bios "$FW" -device virtio-gpu-pci
          -device qemu-xhci -device usb-kbd -device usb-tablet
          -drive "file=$ISO,media=cdrom,if=none,id=cd" -device usb-storage,drive=cd)
    [ "$(uname -m)" = aarch64 ] && [ -w /dev/kvm ] && args+=(-enable-kvm -cpu host)
else
    args=(qemu-system-x86_64 -vga virtio -cdrom "$ISO" -boot d)
    [ "$(uname -m)" = x86_64 ] && [ -w /dev/kvm ] && args+=(-enable-kvm -cpu host)
fi
args+=(-m 4096 -smp 4)
if [ -n "${1:-}" ]; then
    [ -e "$1" ] || truncate -s 16G "$1"
    args+=(-drive "file=$1,format=raw,if=virtio")
fi
exec "${args[@]}"
