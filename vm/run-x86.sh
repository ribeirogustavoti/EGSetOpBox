#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# x86_64 KVM smoke-test VM (Chat Master D-69, D-107).
#
# Usage: vm/run-x86.sh <command>
#   init [--force]   copy the newest built VM image to the persistent disk
#   firstboot        boot the persistent disk with the serial console here
#                    (run initial-setup once, then: sudo poweroff)
#   start            boot a throwaway overlay in the background
#   wait [seconds]   wait until SSH answers (default 180)
#   ssh [command]    run a command in the VM as admin
#   screendump FILE  save the VM screen as PNG
#   stop             power the VM off and remove the overlay
#   status           show whether the VM is running

set -euo pipefail

cache="${XDG_CACHE_HOME:-${HOME}/.cache}/egsob"
kiwi_out="${cache}/kiwi/vm"
vm_dir="${cache}/vm"
disk="${vm_dir}/x86_64.qcow2"
vars="${vm_dir}/OVMF_VARS.fd"
overlay="${vm_dir}/run.qcow2"
qmp="${vm_dir}/qmp.sock"
vfs_sock="${vm_dir}/virtiofs.sock"
qemu_pid="${vm_dir}/qemu.pid"
vfs_pid="${vm_dir}/virtiofsd.pid"

qemu_bin="${QEMU:-qemu-system-x86_64}"
virtiofsd_bin="${VIRTIOFSD:-/usr/libexec/virtiofsd}"
ovmf_code="${OVMF_CODE:-/usr/share/edk2/ovmf/OVMF_CODE.fd}"
ovmf_vars="${OVMF_VARS:-/usr/share/edk2/ovmf/OVMF_VARS.fd}"
ssh_port=2222
repo="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

die() {
	echo "run-x86.sh: $*" >&2
	exit 1
}

is_running() {
	[[ -f "${qemu_pid}" ]] && kill -0 "$(cat "${qemu_pid}")" 2> /dev/null
}

base_args() {
	local drive="$1"
	printf '%s\n' \
		-machine q35,accel=kvm,memory-backend=mem -cpu host -smp 4 -m 4G \
		-object memory-backend-memfd,id=mem,size=4G,share=on \
		-drive "if=pflash,format=raw,readonly=on,file=${ovmf_code}" \
		-drive "if=pflash,format=raw,file=${vars}" \
		-drive "if=virtio,format=qcow2,file=${drive}" \
		-nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${ssh_port}-:22"
}

cmd_init() {
	local image
	if [[ -f "${disk}" && "${1:-}" != "--force" ]]; then
		die "${disk} exists (use init --force)"
	fi
	if is_running; then die "VM is running; stop it first"; fi
	image="$(find "${kiwi_out}" -maxdepth 1 -name '*.qcow2' -printf '%T@ %p\n' 2> /dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)"
	[[ -n "${image}" ]] || die "no built VM image in ${kiwi_out}"
	mkdir -p "${vm_dir}"
	cp --reflink=auto "${image}" "${disk}"
	cp "${ovmf_vars}" "${vars}"
	echo "Persistent disk ${disk} created from ${image}. Next: vm/run-x86.sh firstboot"
}

cmd_firstboot() {
	local args
	[[ -f "${disk}" ]] || die "no persistent disk; run init first"
	if is_running; then die "VM is running; stop it first"; fi
	mapfile -t args < <(base_args "${disk}")
	exec "${qemu_bin}" "${args[@]}" -nographic
}

start_virtiofsd() {
	rm -f "${vfs_sock}"
	"${virtiofsd_bin}" --socket-path="${vfs_sock}" --shared-dir="${repo}" --sandbox=namespace \
		> "${vm_dir}/virtiofsd.log" 2>&1 &
	echo $! > "${vfs_pid}"
	for _ in $(seq 50); do
		[[ -S "${vfs_sock}" ]] && return 0
		sleep 0.1
	done
	die "virtiofsd did not start (see ${vm_dir}/virtiofsd.log)"
}

cmd_start() {
	local args
	[[ -f "${disk}" ]] || die "no persistent disk; run init and firstboot first"
	if is_running; then die "VM is already running"; fi
	rm -f "${overlay}" "${qmp}"
	qemu-img create -q -f qcow2 -b "${disk}" -F qcow2 "${overlay}"
	start_virtiofsd
	mapfile -t args < <(base_args "${overlay}")
	"${qemu_bin}" "${args[@]}" \
		-chardev "socket,id=vfs,path=${vfs_sock}" -device vhost-user-fs-pci,chardev=vfs,tag=egsob \
		-device virtio-vga-gl -display egl-headless \
		-serial "file:${vm_dir}/serial.log" \
		-qmp "unix:${qmp},server=on,wait=off" \
		-daemonize -pidfile "${qemu_pid}"
	echo "VM started (SSH on 127.0.0.1:${ssh_port})"
}

vm_ssh() {
	ssh -p "${ssh_port}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR -o ConnectTimeout=5 admin@127.0.0.1 "$@"
}

cmd_wait() {
	local timeout="${1:-180}" waited=0
	until vm_ssh true 2> /dev/null; do
		((waited += 5))
		((waited < timeout)) || die "SSH not ready after ${timeout} s"
		sleep 5
	done
	echo "VM ready"
}

qmp_send() {
	printf '{"execute":"qmp_capabilities"}\n%s\n' "$1" | socat - "UNIX-CONNECT:${qmp}" > /dev/null
}

cmd_screendump() {
	local out="${1:?usage: screendump FILE.png}"
	is_running || die "VM is not running"
	out="$(realpath -m "${out}")"
	qmp_send "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"${out}\",\"format\":\"png\"}}"
	echo "Screendump saved to ${out}"
}

cmd_stop() {
	if is_running; then
		qmp_send '{"execute":"system_powerdown"}' || true
		for _ in $(seq 60); do
			is_running || break
			sleep 1
		done
		if is_running; then kill "$(cat "${qemu_pid}")"; fi
	fi
	if [[ -f "${vfs_pid}" ]]; then kill "$(cat "${vfs_pid}")" 2> /dev/null || true; fi
	rm -f "${overlay}" "${qmp}" "${vfs_sock}" "${qemu_pid}" "${vfs_pid}"
	echo "VM stopped"
}

main() {
	local cmd="${1:-}"
	shift || true
	case "${cmd}" in
		init) cmd_init "$@" ;;
		firstboot) cmd_firstboot ;;
		start) cmd_start ;;
		wait) cmd_wait "$@" ;;
		ssh) vm_ssh "$@" ;;
		screendump) cmd_screendump "$@" ;;
		stop) cmd_stop ;;
		status) if is_running; then echo running; else echo stopped; fi ;;
		*) sed -n '4,15p' "$0" >&2; exit 2 ;;
	esac
}

main "$@"
