#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# VM smoke test against the libvirt VM "egsob" (Chat Master D-51, D-134).
# Run on the laptop (image host), as a member of the libvirt group, from the
# copied repository files:
#   vm/smoke.sh
# Needs the VM from docs/vm-libvirt.md with initial-setup done. Starts the VM
# if it is off, runs the checks, saves everything to
# ~/.cache/egsob/smoke/<UTC time>/ and exits non-zero if a check fails.
# EGSOB_VM selects another libvirt domain (default: egsob).

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
domain="${EGSOB_VM:-egsob}"
virsh=(virsh -c qemu:///system)
out="${XDG_CACHE_HOME:-${HOME}/.cache}/egsob/smoke/$(date -u +%Y%m%dT%H%M%SZ)"
keys=(up down left right select)
failures=0
ip=""

mkdir -p "${out}"
exec > >(tee "${out}/smoke.log") 2>&1

result() {
	local name="$1" ok="$2"
	if [[ "${ok}" == "yes" ]]; then
		echo "PASS ${name}"
	else
		echo "FAIL ${name}"
		failures=$((failures + 1))
	fi
}

vm_ssh() {
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
		-o ConnectTimeout=5 -o BatchMode=yes "admin@${ip}" "$@"
}

# Runs vm/vivid-cec.sh inside the VM by piping it over SSH.
vivid() {
	vm_ssh bash -s -- "$@" < "${here}/vivid-cec.sh"
}

find_ip() {
	"${virsh[@]}" domifaddr "${domain}" 2> /dev/null |
		awk '/ipv4/ {sub(/\/.*/, "", $4); print $4; exit}'
}

wait_ready() {
	local timeout="$1" waited=0
	if [[ "$("${virsh[@]}" domstate "${domain}")" != "running" ]]; then
		"${virsh[@]}" start "${domain}"
	fi
	until ip="$(find_ip)" && [[ -n "${ip}" ]] && vm_ssh true 2> /dev/null; do
		((waited += 5))
		((waited < timeout)) || return 1
		sleep 5
	done
	echo "VM ${domain} ready at ${ip}"
}

check_version() {
	local actual
	actual="$(vm_ssh egsob 2>&1 || true)"
	echo "egsob prints: ${actual}"
	if [[ "${actual}" =~ ^egsob\ [0-9]+\.[0-9]+\.[0-9]+\ \( ]]; then result version yes; else result version no; fi
}

check_service() {
	local state
	state="$(vm_ssh systemctl is-active egsob 2>&1 || true)"
	echo "egsob.service: ${state}"
	if [[ "${state}" == "active" ]]; then result service yes; else result service no; fi
}

check_cec() {
	local pressed monitor_pid
	vivid setup
	vivid monitor 20 > "${out}/cec-monitor.log" 2>&1 &
	monitor_pid=$!
	sleep 3
	vivid send "${keys[@]}"
	wait "${monitor_pid}" || true
	pressed="$(grep -ci 'user_control_pressed' "${out}/cec-monitor.log" || true)"
	echo "USER_CONTROL_PRESSED received: ${pressed} of ${#keys[@]}"
	if ((pressed >= ${#keys[@]})); then result cec-keys yes; else result cec-keys no; fi
}

collect() {
	vm_ssh journalctl -b --no-pager > "${out}/journal.txt" 2>&1 || true
	vm_ssh journalctl -b -u egsob --no-pager > "${out}/journal-egsob.txt" 2>&1 || true
	if (cd "${out}" && "${virsh[@]}" screenshot "${domain}"); then result screenshot yes; else result screenshot no; fi
}

main() {
	echo "Smoke test output: ${out}"
	if wait_ready 180; then result boot yes; else result boot no; exit 1; fi
	check_version
	check_service
	check_cec
	collect
	echo "Failures: ${failures}"
	((failures == 0))
}

main "$@"
