#!/usr/bin/env bash
# Build the live ISO.
#
#   sudo ./build.sh            build everything
#   sudo ./build.sh clean      delete build/ and out/
#
# Stages (each one is a layer of the system):
#   1 bootstrap   minimal Ubuntu LTS userland        -> build/rootfs
#   2 configure   kernel, packages, desktop, theme   -> build/rootfs
#   3 image       compress the root filesystem       -> build/iso/live
#   4 iso         add GRUB, write bootable ISO       -> out/*.iso
#
# Needs: debootstrap squashfs-tools xorriso mtools grub-pc-bin
#        grub-efi-amd64-bin grub-common  (see README.md)
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BUILD=${BUILD_DIR:-$HERE/build}
OUT=${OUT_DIR:-$HERE/out}
SUITE=${SUITE:-resolute}          # Ubuntu 26.04 LTS
MIRROR=${MIRROR:-http://archive.ubuntu.com/ubuntu}
ROOT=$BUILD/rootfs
ISO=$BUILD/iso

. "$HERE/config/version"
PRETTY="$OS_NAME $OS_VERSION ($OS_CODENAME)"

log() { printf '\n\033[1;32m[BUILD] %s\033[0m\n' "$*"; }
die() { echo "build.sh: $*" >&2; exit 1; }

# The 16 console colours, one hex value per line, from the console theme.
palette() {
    local theme="$HERE/rootfs/usr/share/hud/themes/$CONSOLE_THEME.conf" i
    for i in $(seq 0 15); do
        sed -n "s/^term_$i *= *#\([0-9a-fA-F]\{6\}\).*/\1/p" "$theme"
    done
}

# The palette as kernel parameters, or (with "vtrgb") in setvtrgb's format.
palette_as() {
    local hex r= g= b= s=
    while read -r hex; do
        r+="$s$((16#${hex:0:2}))"; g+="$s$((16#${hex:2:2}))"; b+="$s$((16#${hex:4:2}))"
        s=,
    done < <(palette)
    if [ "$1" = vtrgb ]; then
        printf '%s\n' "$r" "$g" "$b"
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
    # An older debootstrap may not know this release by name; every Ubuntu
    # release uses the same recipe ("gutsy"), so point at that.
    local script=/usr/share/debootstrap/scripts/$SUITE
    [ -e "$script" ] || script=/usr/share/debootstrap/scripts/gutsy
    debootstrap --variant=minbase "$SUITE" "$ROOT" "$MIRROR" "$script"
    touch "$ROOT/.bootstrapped"
}

stage_configure() {
    [ -f "$ROOT/.configured" ] && { log "2/4 configure: already done"; return; }
    log "2/4 configure: kernel, packages, desktop, theme"
    [ "$(palette | wc -l)" -eq 16 ] || die "theme $CONSOLE_THEME lacks term_0..term_15"
    trap umount_all EXIT
    mount -t proc proc "$ROOT/proc"
    mount -t sysfs sys "$ROOT/sys"
    mount --bind /dev "$ROOT/dev"
    mount --bind /dev/pts "$ROOT/dev/pts"

    rm -rf "$ROOT/tmp/build"
    mkdir -p "$ROOT/tmp/build/overlay/etc/hud"
    cp -a "$HERE/rootfs/." "$ROOT/tmp/build/overlay/"
    # The overlay is copied onto / with cp -a, which also applies its owner
    # and modes to existing folders such as /etc and /usr. A checkout
    # belongs to whoever cloned it (on GitHub, the runner's user), so make
    # everything root's and writable only by root before it goes in.
    chown -R 0:0 "$ROOT/tmp/build/overlay"
    chmod -R u+rwX,go+rX,go-w "$ROOT/tmp/build/overlay"
    palette > "$ROOT/tmp/build/overlay/etc/hud/palette"
    palette_as vtrgb > "$ROOT/tmp/build/overlay/etc/hud/vtrgb"
    cp "$HERE/config/packages.list" "$HERE/config/chroot-setup.sh" "$ROOT/tmp/build/"
    cat > "$ROOT/tmp/build/env" <<ENV
OS_NAME="$OS_NAME"
OS_ID="$OS_ID"
OS_VERSION="$OS_VERSION"
OS_CODENAME="$OS_CODENAME"
PRETTY="$PRETTY"
SUITE="$SUITE"
MIRROR="$MIRROR"
PALETTE="$(palette_as kernel)"
ENV
    chroot "$ROOT" /bin/bash /tmp/build/chroot-setup.sh
    umount_all; trap - EXIT
    touch "$ROOT/.configured"
}

stage_image() {
    log "3/4 image: compressing root filesystem"
    rm -rf "$ISO"; mkdir -p "$ISO/live" "$ISO/boot/grub"
    cp "$(ls "$ROOT"/boot/vmlinuz-* | sort -V | tail -1)"    "$ISO/live/vmlinuz"
    cp "$(ls "$ROOT"/boot/initrd.img-* | sort -V | tail -1)" "$ISO/live/initrd.img"
    mksquashfs "$ROOT" "$ISO/live/filesystem.squashfs" \
        -comp zstd -Xcompression-level 19 -noappend -quiet -e .bootstrapped .configured
}

stage_iso() {
    log "4/4 iso: boot loader and ISO image"
    sed -e "s|@PRETTY@|$PRETTY|g" -e "s|@PALETTE@|$(palette_as kernel)|g" \
        "$HERE/iso/boot/grub/grub.cfg" > "$ISO/boot/grub/grub.cfg"
    mkdir -p "$OUT"
    local iso="$OUT/$OS_ID-$OS_VERSION-amd64.iso"
    # grub-mkrescue makes one image that boots from BIOS and UEFI, CD or USB.
    grub-mkrescue -o "$iso" "$ISO" -- -volid "$(echo "$OS_ID" | tr a-z A-Z)" \
        2>"$BUILD/grub-mkrescue.log" \
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
        sed -n '2,5p' "$0"; exit 1 ;;
esac
