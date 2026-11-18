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
# Grow the root partition on first boot
#--------------------------------------
mkdir -p /etc/repart.d
printf '[Partition]\nType=root\n' > /etc/repart.d/50-root.conf

#--------------------------------------
# Accounts (D-104): root locked, admin created by initial-setup
#--------------------------------------
passwd -d root
passwd -l root
systemctl enable initial-setup.service
touch /etc/reconfigSys

#--------------------------------------
# SSH: keys only, no root, engineer key preset for admin (D-66, D-104)
#--------------------------------------
cat > /etc/ssh/sshd_config.d/40-egsob.conf << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
EOF
install -d -m 0755 /etc/ssh/authorized_keys.d
cat > /etc/ssh/authorized_keys.d/admin << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIk3Qf+zcoT3S/ylqqTlaJeOCKlQvLmLweXorRNNz1F
EOF
chmod 0644 /etc/ssh/authorized_keys.d/admin
systemctl enable sshd.service

#--------------------------------------
# Wi-Fi from the boot-partition file (D-106)
#--------------------------------------
chmod 0755 /usr/libexec/egsob/wifi-import.sh
systemctl enable egsob-wifi-import.service

#--------------------------------------
# Raspberry Pi: U-Boot next to the Pi firmware on the ESP
#--------------------------------------
if [[ "${profiles}" == *"Pi"* ]]; then
	cp -a /usr/share/uboot/rpi_arm64/u-boot.bin /boot/efi/rpi-u-boot.bin
fi

#--------------------------------------
# VM: repository shared from the dev host with virtiofs, read-only (D-107)
#--------------------------------------
if [[ "${profiles}" == *"VM"* ]]; then
	mkdir -p /mnt/egsob
	cat > /etc/systemd/system/mnt-egsob.mount << 'EOF'
[Unit]
Description=EGSetOpBox repository shared from the dev host (virtiofs)

[Mount]
What=egsob
Where=/mnt/egsob
Type=virtiofs
Options=ro,nofail

[Install]
WantedBy=multi-user.target
EOF
	systemctl enable mnt-egsob.mount
fi

systemctl set-default multi-user.target
