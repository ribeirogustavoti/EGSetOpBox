#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Imports Wi-Fi credentials from egsob-wifi.txt on the ESP into NetworkManager
# and deletes the file (Chat Master D-100, D-106). File format, one per line:
#   SSID=<network name>
#   PSK=<passphrase>
# The passphrase is never printed.

set -euo pipefail

file="${1:-/boot/efi/egsob-wifi.txt}"
[[ -f "${file}" ]] || exit 0

ssid=""
psk=""
while IFS= read -r line || [[ -n "${line}" ]]; do
	line="${line%$'\r'}"
	case "${line}" in
		SSID=*) ssid="${line#SSID=}" ;;
		PSK=*) psk="${line#PSK=}" ;;
	esac
done < "${file}"

rm -f -- "${file}"
sync

if [[ -z "${ssid}" || -z "${psk}" ]]; then
	echo "egsob-wifi.txt ignored: it needs an SSID= line and a PSK= line" >&2
	exit 1
fi

nmcli connection delete egsob-wifi > /dev/null 2>&1 || true
nmcli connection add type wifi con-name egsob-wifi ssid "${ssid}" \
	wifi-sec.key-mgmt wpa-psk wifi-sec.psk "${psk}" connection.autoconnect yes > /dev/null
nmcli connection up egsob-wifi > /dev/null || echo "egsob-wifi created; activation will be retried by NetworkManager" >&2
echo "Wi-Fi connection egsob-wifi created for SSID ${ssid}"
