#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# vivid CEC emulation inside the smoke-test VM (Chat Master D-51, D-107, D-138).
# Runs in the VM as admin: /dev/cec* is group wheel, and the VM-only sudoers
# file lets admin run v4l2-ctl (vivid link) and cec-ctl --monitor as root.
# vm/smoke.sh pipes it over SSH: ssh admin@<VM> bash -s -- <command> < vm/vivid-cec.sh
#   setup                 connect vivid's HDMI input to its HDMI output, make the
#                         input adapter a TV and the output adapter a playback
#                         device "EGSetOpBox", and record its logical address
#   send KEY...           TV sends USER_CONTROL_PRESSED/RELEASED for each key
#                         (cec-ctl ui-cmd names, e.g. up down left right select)
#   monitor SECONDS       print what the playback adapter receives
#   topology              show the CEC topology seen by the playback adapter

set -euo pipefail

map_file=/tmp/egsob-vivid-cec.env
# vivid capture control that links HDMI input 0 to an output; menu value 2 is
# "Output HDMI 000-0" (value 0, the default, is the test pattern generator).
link_ctrl=hdmi_000_0_is_connected_to
link_value=2

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

# Prints the vivid video device that has the HDMI input link control.
find_link_device() {
	local dev
	for dev in /dev/video*; do
		[[ -e "${dev}" ]] || continue
		if sudo -n v4l2-ctl -d "${dev}" --get-ctrl "${link_ctrl}" > /dev/null 2>&1; then
			echo "${dev}"
			return 0
		fi
	done
	return 1
}

# Prints the logical address the adapter claimed, waiting up to 10 seconds.
wait_for_la() {
	local dev="$1" la tries=0
	while ((tries < 20)); do
		la="$(cec-ctl -d "${dev}" | sed -n 's/^[[:space:]]*Logical Address[[:space:]]*: \([0-9][0-9]*\) (.*/\1/p' | head -1)"
		if [[ -n "${la}" ]]; then
			echo "${la}"
			return 0
		fi
		sleep 0.5
		tries=$((tries + 1))
	done
	return 1
}

cmd_setup() {
	local tv box dev video box_la
	[[ -d /sys/module/vivid ]] || die "the vivid module is not loaded"
	video="$(find_link_device)" || die "no vivid device with ${link_ctrl} (sudo -n v4l2-ctl must work)"
	sudo -n v4l2-ctl -d "${video}" --set-ctrl "${link_ctrl}=${link_value}"
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
	box_la="$(wait_for_la "${box}")" || die "the playback adapter ${box} got no logical address"
	printf 'TV=%s\nBOX=%s\nBOX_LA=%s\n' "${tv}" "${box}" "${box_la}" | tee "${map_file}"
}

tv_dev=""
box_dev=""
box_la=""

load_map() {
	[[ -f "${map_file}" ]] || die "run setup first"
	tv_dev="$(sed -n 's/^TV=//p' "${map_file}")"
	box_dev="$(sed -n 's/^BOX=//p' "${map_file}")"
	box_la="$(sed -n 's/^BOX_LA=//p' "${map_file}")"
}

cmd_send() {
	local key
	load_map
	for key in "$@"; do
		cec-ctl -d "${tv_dev}" --to "${box_la}" --user-control-pressed "ui-cmd=${key}" > /dev/null
		cec-ctl -d "${tv_dev}" --to "${box_la}" --user-control-released > /dev/null
		sleep 0.5
	done
}

cmd_monitor() {
	load_map
	timeout "${1:?usage: monitor SECONDS}" sudo -n cec-ctl -d "${box_dev}" --monitor || true
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
