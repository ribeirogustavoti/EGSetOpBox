#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Build an EGSetOpBox disk image on the image host, the laptop with kiwi-ng
# (Chat Master D-129, D-130). Keep this file next to the os/kiwi/ directory.
#
# Usage: os/build-image.sh VM|Pi
#   VM  copy target/release/egsob from the dev box over SSH, then
#       kiwi-ng system build (x86_64 qcow2)
#   Pi  download the newest successful "release" workflow artifact
#       (egsob-aarch64) with gh, then kiwi-ng system boxbuild (aarch64 raw)
# Settings: EGSOB_DEV (SSH target of the dev box), EGSOB_DEV_REPO (repository
# path on the dev box, relative to its home directory).
# Output: ~/.cache/egsob/kiwi/vm or ~/.cache/egsob/kiwi/pi

set -euo pipefail

dev="${EGSOB_DEV:-grbonis@192.168.122.13}"
dev_repo="${EGSOB_DEV_REPO:-Development/EGSetOpBox}"
github_repo="ribeirogustavoti/EGSetOpBox"
here="$(cd "$(dirname "$0")" && pwd)"
description="${here}/kiwi"
cache="${XDG_CACHE_HOME:-${HOME}/.cache}/egsob/kiwi"

die() {
	echo "build-image.sh: $*" >&2
	exit 1
}

fetch_vm_binary() {
	local dest="$1"
	echo "Copying ${dev}:${dev_repo}/target/release/egsob"
	scp -q "${dev}:${dev_repo}/target/release/egsob" "${dest}" ||
		die "no release binary on the dev box; run 'cargo build --release -p egsob-app' there"
}

fetch_pi_binary() {
	local dest="$1" run_id download
	run_id="$(gh run list -R "${github_repo}" --workflow release.yml --status success \
		--limit 1 --json databaseId --jq '.[0].databaseId')"
	[[ -n "${run_id}" ]] || die "no successful release.yml run; start one with 'gh workflow run release.yml'"
	echo "Downloading artifact egsob-aarch64 from run ${run_id}"
	download="$(mktemp -d)"
	gh run download "${run_id}" -R "${github_repo}" -n egsob-aarch64 -D "${download}"
	mv "${download}/egsob" "${dest}"
	rmdir "${download}"
}

stage() {
	local profile="$1" staged="$2" binary
	cp -a "${description}/." "${staged}/"
	binary="${staged}/root/usr/bin/egsob"
	mkdir -p "$(dirname "${binary}")"
	if [[ "${profile}" == "VM" ]]; then fetch_vm_binary "${binary}"; else fetch_pi_binary "${binary}"; fi
	chmod 0755 "${binary}"
}

build() {
	local profile="$1" staged="$2" out="$3"
	sudo rm -rf "${out}"
	if [[ "${profile}" == "VM" ]]; then
		sudo kiwi-ng --profile=VM --type=oem --kiwi-file=egsob.kiwi system build \
			--description "${staged}" --target-dir "${out}"
	else
		sudo kiwi-ng --profile=Pi --type=oem --kiwi-file=egsob.kiwi system boxbuild \
			--box universal --aarch64 --machine virt --cpu cortex-a72 --box-smp-cpus 4 \
			--box-memory 8G --no-accel -- --description "${staged}" --target-dir "${out}"
	fi
	sudo chown -R "$(id -u):$(id -g)" "${out}"
}

main() {
	local profile="${1:-}" staged out
	[[ "${profile}" == "VM" || "${profile}" == "Pi" ]] || { sed -n '4,15p' "$0" >&2; exit 2; }
	[[ -f "${description}/egsob.kiwi" ]] || die "${description}/egsob.kiwi not found"
	staged="$(mktemp -d)"
	trap 'rm -rf "${staged}"' EXIT
	stage "${profile}" "${staged}"
	out="${cache}/$(tr '[:upper:]' '[:lower:]' <<< "${profile}")"
	build "${profile}" "${staged}" "${out}"
	echo "Image ready in ${out}:"
	ls -l "${out}"
}

main "$@"
