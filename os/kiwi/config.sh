#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# KIWI config.sh: runs inside the image root after the packages are installed
# (Chat Master D-66, D-104, D-105).

set -euxo pipefail

# shellcheck source=/dev/null
test -f /.kconfig && . /.kconfig
# shellcheck source=/dev/null
test -f /.profile && . /.profile

# shellcheck disable=SC2154 # kiwi_profiles is set by /.profile
profiles="${kiwi_profiles:-}"
echo "Configure image for profile(s): ${profiles}"

#--------------------------------------
# Machine identity: generated on first boot
#--------------------------------------
rm -f /etc/machine-id
echo 'uninitialized' > /etc/machine-id
rm -f /var/lib/systemd/random-seed
echo 'egsob' > /etc/hostname

#--------------------------------------
# GRUB defaults (as Fedora's KIWI descriptions)
#--------------------------------------
{
	echo 'GRUB_DEFAULT=saved'
	echo 'GRUB_DISABLE_SUBMENU=true'
	echo 'GRUB_DISABLE_RECOVERY=true'
} >> /etc/default/grub

#--------------------------------------
# No partition growth at boot: systemd-repart masked (D-135)
#--------------------------------------
systemctl mask systemd-repart.service

#--------------------------------------
# Accounts (D-104): root locked, admin created by initial-setup
#--------------------------------------
passwd -d root
passwd -l root
systemctl enable initial-setup.service
touch /etc/reconfigSys

#--------------------------------------
# SSH: keys only, no root, engineer keys preset for admin (D-66, D-104, D-135):
# image host (laptop) and dev box (fedora-devel)
#--------------------------------------
cat > /etc/ssh/sshd_config.d/40-egsob.conf << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
EOF
install -d -m 0755 /etc/ssh/authorized_keys.d
cat > /etc/ssh/authorized_keys.d/admin << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIByjUOCUuddmfoCSchNf4ZVy0WAqgFu6hnmh8TljEQ6+ grbonis@fedora
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIk3Qf+zcoT3S/ylqqTlaJeOCKlQvLmLweXorRNNz1F
EOF
chmod 0644 /etc/ssh/authorized_keys.d/admin
systemctl enable sshd.service

#--------------------------------------
# RPM Fusion free and full ffmpeg (D-05, D-141): the release package brings the
# repository definitions and signing keys; ffmpeg is then installed signed
#--------------------------------------
dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
dnf -y install --allowerasing ffmpeg ffmpeg-libs
dnf clean all

#--------------------------------------
# Wi-Fi from the boot-partition file (D-106)
#--------------------------------------
chmod 0755 /usr/libexec/egsob/wifi-import.sh
systemctl enable egsob-wifi-import.service

#--------------------------------------
# egsob binary (staged by os/build-image.sh), user (sysusers.d) and the TV
# interface service (D-122, D-123, D-130)
#--------------------------------------
test -x /usr/bin/egsob || { echo 'config.sh: /usr/bin/egsob missing; build with os/build-image.sh' >&2; exit 1; }
systemd-sysusers /usr/lib/sysusers.d/egsob.conf
systemctl enable egsob.service
# initial-setup empties /etc/hostname; this unit restores egsob (D-140)
systemctl enable egsob-hostname.service

#--------------------------------------
# Raspberry Pi: U-Boot next to the Pi firmware on the ESP
#--------------------------------------
if [[ "${profiles}" == *"Pi"* ]]; then
	cp -a /usr/share/uboot/rpi_arm64/u-boot.bin /boot/efi/rpi-u-boot.bin
fi

#--------------------------------------
# VM: CEC emulation for the smoke test (D-107, D-134)
#--------------------------------------
if [[ "${profiles}" == *"VM"* ]]; then
	# vivid emulates an HDMI input (TV side) and output (box side) with CEC (D-51)
	echo 'vivid' > /etc/modules-load.d/vivid.conf
	# VM only: admin (wheel) drives the CEC adapters without sudo (D-107)
	echo 'SUBSYSTEM=="cec", GROUP="wheel", MODE="0660"' > /etc/udev/rules.d/60-egsob-vm-cec.rules
	# VM only: admin runs v4l2-ctl (vivid link) and cec-ctl --monitor as root
	# without a password, for the smoke test (D-138)
	echo 'admin ALL=(root) NOPASSWD: /usr/bin/cec-ctl, /usr/bin/v4l2-ctl' > /etc/sudoers.d/egsob-vm-cec
	chmod 0440 /etc/sudoers.d/egsob-vm-cec
fi

systemctl set-default multi-user.target
