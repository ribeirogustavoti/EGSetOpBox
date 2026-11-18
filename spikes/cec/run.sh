#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

EGSOB_CEC_DIR="${EGSOB_CEC_DIR:-${HOME}/egsob-cec}"
CEC_DEV=/dev/cec0

# Keys from the issue: D-pad, OK, Back, Play, Pause, Stop, FF, RW, CH+/-, digits 0-9.
KEYS=(
    up down left right ok back
    play pause stop fastforward rewind
    channel-up channel-down
    0 1 2 3 4 5 6 7 8 9
)

usage() {
    printf 'Usage: %s {precheck|keys playback|keys tuner|power}\n' "$0" >&2
    exit 1
}

precheck() {
    local log="${EGSOB_CEC_DIR}/precheck.log"
    {
        printf '=== /dev/cec* ===\n'
        ls -l /dev/cec* 2>&1 || true
    } | tee "${log}"
    if [[ ! -c "${CEC_DEV}" ]]; then
        printf 'ERROR: %s not found or not a character device\n' "${CEC_DEV}" \
            | tee -a "${log}"
        exit 1
    fi
    if [[ ! -r "${CEC_DEV}" ]]; then
        printf 'ERROR: %s not readable by %s\n' "${CEC_DEV}" "$(id -un)" \
            | tee -a "${log}"
        exit 1
    fi
    {
        printf '=== physical address ===\n'
        cec-ctl -d "${CEC_DEV}" --physical-address 2>&1
        printf '=== topology ===\n'
        cec-ctl -d "${CEC_DEV}" --show-topology 2>&1
    } | tee -a "${log}"
}

get_phys_addr() {
    cec-ctl -d "${CEC_DEV}" --physical-address 2>&1 \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
        | head -1
}

announce_active() {
    local addr
    addr=$(get_phys_addr)
    cec-ctl -d "${CEC_DEV}" --active-source "phys-addr=${addr}" 2>/dev/null || true
}

extract_code() {
    # Print the user-control-code label from the first matching PRESSED/RELEASED block.
    local type="$1" file="$2"
    grep -A1 "USER_CONTROL_${type}" "${file}" \
        | grep -o 'user-control-code:.*' \
        | sed 's/user-control-code:[[:space:]]*//' \
        | head -1 \
        || printf 'none'
}

record_key() {
    local key="$1" keytmp="$2" logfile="$3" tsvfile="$4"
    printf '\nPRESS: %s  (5 s window)\n' "${key}"
    timeout 5 cec-ctl -d "${CEC_DEV}" --monitor > "${keytmp}" 2>&1 || true
    cat "${keytmp}" >> "${logfile}"
    local pressed released
    pressed=$(extract_code PRESSED "${keytmp}")
    released=$(extract_code RELEASED "${keytmp}")
    printf '%s\t%s\t%s\n' "${key}" "${pressed}" "${released}" >> "${tsvfile}"
}

run_keys() {
    local type="$1"
    local logfile="${EGSOB_CEC_DIR}/keys-${type}.log"
    local tsvfile="${EGSOB_CEC_DIR}/keys-${type}.tsv"
    local keytmp="${EGSOB_CEC_DIR}/.key.tmp"

    cec-ctl -d "${CEC_DEV}" --osd-name EGSetOpBox "--${type}" 2>&1
    announce_active

    : > "${logfile}"
    printf 'key\tpressed\treleased\n' > "${tsvfile}"

    local key
    for key in "${KEYS[@]}"; do
        record_key "${key}" "${keytmp}" "${logfile}" "${tsvfile}"
    done

    rm -f "${keytmp}"
    printf '\nLog: %s\nTSV: %s\n' "${logfile}" "${tsvfile}"
}

power_step() {
    local n="$1" msg="$2" secs="$3" logfile="$4"
    printf '\n[STEP %s] %s — monitoring %s s\n' "${n}" "${msg}" "${secs}"
    printf '[STEP %s: %s]\n' "${n}" "${msg}" >> "${logfile}"
    timeout "${secs}" cec-ctl -d "${CEC_DEV}" --monitor >> "${logfile}" 2>&1 || true
}

run_power() {
    local logfile="${EGSOB_CEC_DIR}/power.log"
    : > "${logfile}"

    cec-ctl -d "${CEC_DEV}" --osd-name EGSetOpBox --playback 2>&1
    announce_active

    power_step 1 "Put the TV in STANDBY now"             25 "${logfile}"
    power_step 2 "Power the TV ON now"                   25 "${logfile}"
    power_step 3 "Switch the TV to ANOTHER input now"    20 "${logfile}"
    power_step 4 "Switch BACK to the Pi input now"       20 "${logfile}"

    printf '\nLog: %s\n' "${logfile}"
}

main() {
    [[ $# -ge 1 ]] || usage
    mkdir -p "${EGSOB_CEC_DIR}"

    case "$1" in
        precheck)
            precheck
            ;;
        keys)
            if [[ $# -lt 2 ]]; then
                printf 'Usage: %s keys {playback|tuner}\n' "$0" >&2
                exit 1
            fi
            case "$2" in
                playback|tuner)
                    precheck
                    run_keys "$2"
                    ;;
                *)
                    printf 'Unknown device type: %s\n' "$2" >&2
                    exit 1
                    ;;
            esac
            ;;
        power)
            precheck
            run_power
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
