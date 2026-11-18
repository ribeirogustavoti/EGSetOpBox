#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# KIWI editbootinstall hook for the Pi profile (Chat Master D-105): give the
# ESP (partition 1) the legacy FAT16 MBR type 0x06 so the Raspberry Pi
# firmware reads it, as Fedora's editbootinstall_rpilegacy.sh does.
# KIWI calls it with: <disk image name> <boot device name>.

set -euxo pipefail

devname="$2"
loopname="${devname%p?}"
loopdev="/dev/${loopname#/dev/}"

sfdisk --change-id "${loopdev}" 1 6
