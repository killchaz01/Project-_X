#!/usr/bin/env bash
# Boot the built ISO in a QEMU window.
#   scripts/run-qemu.sh              boot the live ISO
#   scripts/run-qemu.sh disk.img     also attach a disk to install onto
#                                    (created as 16 GB if it doesn't exist)
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ISO=$(ls "$HERE"/out/cyberdyne-os-*.iso 2>/dev/null | tail -1)
[ -n "$ISO" ] || { echo "no ISO in out/ - run sudo ./build.sh first" >&2; exit 1; }

args=(-m 2048 -smp 2 -cdrom "$ISO" -boot d)
case "$(uname -s)" in
    Linux)  [ -w /dev/kvm ] && args+=(-enable-kvm -cpu host) ;;
    Darwin) [ "$(uname -m)" = x86_64 ] && args+=(-accel hvf -cpu host) ;;
esac
if [ -n "${1:-}" ]; then
    [ -e "$1" ] || truncate -s 16G "$1"
    args+=(-drive "file=$1,format=raw")
fi
exec qemu-system-x86_64 "${args[@]}"
