#!/bin/bash
# Runs inside the new root filesystem (called by build.sh).
# Inputs in /tmp/cyb: packages.list, overlay/, env
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C
. /tmp/cyb/env

# Stop package scripts from starting services inside the build chroot.
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

echo "== packages"
cat > /etc/apt/sources.list <<SRC
deb $MIRROR $SUITE main universe restricted
deb $MIRROR $SUITE-updates main universe restricted
deb http://security.ubuntu.com/ubuntu $SUITE-security main universe restricted
SRC
apt-get update
apt-get install -y --no-install-recommends \
    $(sed 's/#.*//' /tmp/cyb/packages.list)

echo "== identity"
# Keep Ubuntu's file out of the way so package upgrades don't undo the rename.
dpkg-divert --quiet --add --rename --divert /usr/lib/os-release.ubuntu /usr/lib/os-release
cp -a /tmp/cyb/overlay/. /
mv /etc/os-release.cyberdyne /usr/lib/os-release
ln -sf ../usr/lib/os-release /etc/os-release
sed -i -e "s|@PRETTY@|$PRETTY|g" -e "s|@NAME@|$OS_NAME|g" \
       -e "s|@VERSION@|$OS_VERSION|g" -e "s|@CODENAME@|$OS_CODENAME|g" \
       -e "s|@SUITE@|$SUITE|g" -e "s|@PALETTE@|$PALETTE|g" \
    /usr/lib/os-release /etc/issue /etc/default/grub
rm -f /etc/update-motd.d/* /etc/legal
# console-setup repaints the console palette at boot from /etc/vtrgb;
# point that at ours so the HUD colours set on the kernel command line stay.
update-alternatives --quiet --install /etc/vtrgb vtrgb /etc/cyberdyne/vtrgb 100
# Ubuntu ships NetworkManager ignoring wired ports unless netplan hands them
# over. An empty file of the same name in /etc switches that off.
mkdir -p /etc/NetworkManager/conf.d
: > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

echo "== locale"
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

echo "== users"
# Live-session account. cyberdyne-install replaces it with your own.
for g in audio video plugdev netdev; do groupadd -f "$g"; done
id dyson >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev dyson
echo 'dyson:skynet' | chpasswd
passwd -l root >/dev/null
cp /etc/skel/.bashrc /etc/skel/.profile /root/

echo "== initramfs"
update-initramfs -u -k all

echo "== cleanup"
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/cyb /usr/sbin/policy-rc.d
rm -f /etc/machine-id /var/lib/dbus/machine-id
: > /etc/machine-id
