#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# vivid CEC emulation inside the smoke-test VM (Chat Master D-51, D-107).
# Runs in the VM as admin (no sudo; /dev/cec* is group wheel in the VM).
# vm/smoke.sh pipes it over SSH: ssh admin@<VM> bash -s -- <command> < vm/vivid-cec.sh
#   setup                 make vivid's HDMI input adapter a TV and its
#                         HDMI output adapter a playback device "EGSetOpBox"
#   send KEY...           TV sends USER_CONTROL_PRESSED/RELEASED for each key
#                         (cec-ctl ui-cmd names, e.g. up down left right select)
#   monitor SECONDS       print what the playback adapter receives
#   topology              show the CEC topology seen by the playback adapter

set -euo pipefail

map_file=/tmp/egsob-vivid-cec.env

die() {
	echo "vivid-cec.sh: $*" >&2
	exit 1
}

find_adapter() {
	local pattern="$1" dev
	for dev in /dev/cec*; do
		[[ -e "${dev}" ]] || continue
		if cec-ctl -d "${dev}" 2> /dev/null | grep -q "${pattern}"; then
			echo "${dev}"
			return 0
		fi
	done
	return 1
}

cmd_setup() {
	local tv box dev
	[[ -d /sys/module/vivid ]] || die "the vivid module is not loaded"
	tv="$(find_adapter 'vivid-[0-9]*-vid-cap')" || tv=""
	box="$(find_adapter 'vivid-[0-9]*-vid-out')" || box=""
	if [[ -z "${tv}" || -z "${box}" ]]; then
		for dev in /dev/cec*; do
			echo "== ${dev}" >&2
			cec-ctl -d "${dev}" >&2 || true
		done
		die "could not find the vivid HDMI input/output CEC adapters"
	fi
	cec-ctl -d "${tv}" --tv > /dev/null
	cec-ctl -d "${box}" --playback --osd-name EGSetOpBox > /dev/null
	printf 'TV=%s\nBOX=%s\n' "${tv}" "${box}" | tee "${map_file}"
}

tv_dev=""
box_dev=""

load_map() {
	[[ -f "${map_file}" ]] || die "run setup first"
	tv_dev="$(sed -n 's/^TV=//p' "${map_file}")"
	box_dev="$(sed -n 's/^BOX=//p' "${map_file}")"
}

cmd_send() {
	local key
	load_map
	for key in "$@"; do
		cec-ctl -d "${tv_dev}" --to 4 --user-control-pressed "ui-cmd=${key}" > /dev/null
		cec-ctl -d "${tv_dev}" --to 4 --user-control-released > /dev/null
		sleep 0.5
	done
}

cmd_monitor() {
	load_map
	timeout "${1:?usage: monitor SECONDS}" cec-ctl -d "${box_dev}" --monitor || true
}

main() {
	local cmd="${1:-}"
	shift || true
	case "${cmd}" in
		setup) cmd_setup ;;
		send) cmd_send "$@" ;;
		monitor) cmd_monitor "$@" ;;
		topology) load_map; cec-ctl -d "${box_dev}" --show-topology ;;
		*) echo 'usage: vivid-cec.sh setup | send KEY... | monitor SECONDS | topology' >&2; exit 2 ;;
	esac
}

main "$@"
