#!/usr/bin/env bash
# Build the Cyberdyne OS live ISO.
#
#   sudo ./build.sh            build everything
#   sudo ./build.sh clean      delete build/ and out/
#
# Stages (each one is a layer of the system):
#   1 bootstrap   minimal Ubuntu LTS userland          -> build/rootfs
#   2 configure   kernel, packages, Cyberdyne theme  -> build/rootfs
#   3 image       compress the root filesystem       -> build/iso/live
#   4 iso         add GRUB, write bootable ISO       -> out/*.iso
#
# Needs: debootstrap squashfs-tools xorriso mtools grub-pc-bin
#        grub-efi-amd64-bin grub-common  (see README.md)
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BUILD=${BUILD_DIR:-$HERE/build}
OUT=${OUT_DIR:-$HERE/out}
SUITE=${SUITE:-noble}
MIRROR=${MIRROR:-http://archive.ubuntu.com/ubuntu}
ROOT=$BUILD/rootfs
ISO=$BUILD/iso

. "$HERE/config/version"
PRETTY="$OS_NAME $OS_VERSION ($OS_CODENAME)"

log() { printf '\n\033[1;31m[CYBERDYNE] %s\033[0m\n' "$*"; }
die() { echo "build.sh: $*" >&2; exit 1; }

# Turn config/palette into vt.default_red=..,.. vt.default_grn=.. vt.default_blu=..
palette_cmdline() {
    local idx hex _ r= g= b= s=
    while read -r idx hex _; do
        case $idx in [0-9]*) ;; *) continue ;; esac
        r+="$s$((16#${hex:0:2}))"; g+="$s$((16#${hex:2:2}))"; b+="$s$((16#${hex:4:2}))"
        s=,
    done < "$HERE/config/palette"
    if [ "${1:-}" = vtrgb ]; then
        printf '%s\n' "$r" "$g" "$b"      # the format setvtrgb(8) reads
    else
        echo "vt.default_red=$r vt.default_grn=$g vt.default_blu=$b"
    fi
}

umount_all() {
    for m in dev/pts dev proc sys; do
        mountpoint -q "$ROOT/$m" && umount -l "$ROOT/$m"
    done
    return 0
}

stage_bootstrap() {
    [ -f "$ROOT/.bootstrapped" ] && { log "1/4 bootstrap: already done"; return; }
    log "1/4 bootstrap: Ubuntu $SUITE base"
    rm -rf "$ROOT"; mkdir -p "$ROOT"
    debootstrap --variant=minbase "$SUITE" "$ROOT" "$MIRROR"
    touch "$ROOT/.bootstrapped"
}

stage_configure() {
    [ -f "$ROOT/.configured" ] && { log "2/4 configure: already done"; return; }
    log "2/4 configure: kernel, packages, theme"
    trap umount_all EXIT
    mount -t proc proc "$ROOT/proc"
    mount -t sysfs sys "$ROOT/sys"
    mount --bind /dev "$ROOT/dev"
    mount --bind /dev/pts "$ROOT/dev/pts"

    mkdir -p "$ROOT/tmp/cyb/overlay/etc/cyberdyne"
    cp -a "$HERE/rootfs/." "$ROOT/tmp/cyb/overlay/"
    cp "$HERE/config/palette" "$ROOT/tmp/cyb/overlay/etc/cyberdyne/palette"
    palette_cmdline vtrgb > "$ROOT/tmp/cyb/overlay/etc/cyberdyne/vtrgb"
    cp "$HERE/config/packages.list" "$HERE/config/chroot-setup.sh" "$ROOT/tmp/cyb/"
    cat > "$ROOT/tmp/cyb/env" <<ENV
OS_NAME="$OS_NAME"
OS_VERSION="$OS_VERSION"
OS_CODENAME="$OS_CODENAME"
PRETTY="$PRETTY"
SUITE="$SUITE"
MIRROR="$MIRROR"
PALETTE="$(palette_cmdline)"
ENV
    chroot "$ROOT" /bin/bash /tmp/cyb/chroot-setup.sh
    umount_all; trap - EXIT
    touch "$ROOT/.configured"
}

stage_image() {
    log "3/4 image: compressing root filesystem"
    rm -rf "$ISO"; mkdir -p "$ISO/live" "$ISO/boot/grub"
    cp "$(ls "$ROOT"/boot/vmlinuz-* | sort -V | tail -1)"    "$ISO/live/vmlinuz"
    cp "$(ls "$ROOT"/boot/initrd.img-* | sort -V | tail -1)" "$ISO/live/initrd.img"
    mksquashfs "$ROOT" "$ISO/live/filesystem.squashfs" \
        -comp xz -noappend -quiet -e .bootstrapped .configured
}

stage_iso() {
    log "4/4 iso: boot loader and ISO image"
    sed -e "s|@PRETTY@|$PRETTY|g" -e "s|@PALETTE@|$(palette_cmdline)|g" \
        "$HERE/iso/boot/grub/grub.cfg" > "$ISO/boot/grub/grub.cfg"
    mkdir -p "$OUT"
    local iso="$OUT/cyberdyne-os-$OS_VERSION-amd64.iso"
    # grub-mkrescue makes one image that boots from BIOS and UEFI, CD or USB.
    grub-mkrescue -o "$iso" "$ISO" -- -volid CYBERDYNE 2>"$BUILD/grub-mkrescue.log" \
        || { cat "$BUILD/grub-mkrescue.log"; die "grub-mkrescue failed"; }
    (cd "$OUT" && sha256sum "$(basename "$iso")" > "$(basename "$iso").sha256")
    log "done: $iso ($(du -h "$iso" | cut -f1))"
}

case "${1:-all}" in
    clean)
        umount_all; rm -rf "$BUILD" "$OUT" ;;
    all)
        [ "$(id -u)" -eq 0 ] || die "must run as root (sudo ./build.sh)"
        for t in debootstrap mksquashfs xorriso grub-mkrescue mformat; do
            command -v "$t" >/dev/null || die "missing tool: $t (see README.md)"
        done
        [ -d /usr/lib/grub/x86_64-efi ] || die "missing grub-efi-amd64-bin"
        [ -d /usr/lib/grub/i386-pc ]    || die "missing grub-pc-bin"
        mkdir -p "$BUILD"
        stage_bootstrap; stage_configure; stage_image; stage_iso ;;
    *)
        sed -n '2,6p' "$0"; exit 1 ;;
esac
