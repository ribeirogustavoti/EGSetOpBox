#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# VM smoke test (Chat Master D-51, D-108). Run on the dev host from the repo:
#   vm/smoke.sh
# Needs a persistent VM disk (vm/run-x86.sh init + firstboot). Builds egsob,
# boots a throwaway VM, runs the checks, saves everything to
# ~/.cache/egsob/smoke/<UTC time>/ and exits non-zero if a check fails.

set -euo pipefail

repo="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
vm="${repo}/vm/run-x86.sh"
out="${XDG_CACHE_HOME:-${HOME}/.cache}/egsob/smoke/$(date -u +%Y%m%dT%H%M%SZ)"
keys=(up down left right select)
failures=0

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

cleanup() {
	"${vm}" stop > /dev/null 2>&1 || true
}
trap cleanup EXIT

check_version() {
	local expected actual
	expected="egsob $(cargo metadata --no-deps --format-version 1 --manifest-path "${repo}/Cargo.toml" |
		jq -r '.packages[] | select(.name == "egsob-app") | .version')"
	actual="$("${vm}" ssh /mnt/egsob/target/debug/egsob 2>&1 || true)"
	echo "expected prefix: ${expected} / got: ${actual}"
	if [[ "${actual}" == "${expected} "* ]]; then result version yes; else result version no; fi
}

check_cec() {
	local pressed monitor_pid
	"${vm}" ssh /mnt/egsob/vm/vivid-cec.sh setup
	"${vm}" ssh /mnt/egsob/vm/vivid-cec.sh monitor 20 > "${out}/cec-monitor.log" 2>&1 &
	monitor_pid=$!
	sleep 3
	"${vm}" ssh /mnt/egsob/vm/vivid-cec.sh send "${keys[@]}"
	wait "${monitor_pid}" || true
	pressed="$(grep -ci 'user_control_pressed' "${out}/cec-monitor.log" || true)"
	echo "USER_CONTROL_PRESSED received: ${pressed} of ${#keys[@]}"
	if ((pressed >= ${#keys[@]})); then result cec-keys yes; else result cec-keys no; fi
}

collect() {
	"${vm}" ssh journalctl -b --no-pager > "${out}/journal.txt" 2>&1 || true
	"${vm}" ssh journalctl -b -u egsob --no-pager > "${out}/journal-egsob.txt" 2>&1 || true
	if "${vm}" screendump "${out}/screen.png"; then result screendump yes; else result screendump no; fi
}

main() {
	echo "Smoke test output: ${out}"
	cargo build -p egsob-app --manifest-path "${repo}/Cargo.toml"
	"${vm}" start
	if "${vm}" wait 180; then result boot yes; else result boot no; exit 1; fi
	check_version
	check_cec
	collect
	echo "Failures: ${failures}"
	((failures == 0))
}

main "$@"
