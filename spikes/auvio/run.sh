#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

EGSOB_AUVIO_DIR="${EGSOB_AUVIO_DIR:-${HOME}/egsob-auvio}"
YTDLP="${YTDLP:-}"
HWDEC="${HWDEC:-v4l2m2m-copy}"

WIDEVINE="urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"
PLAYREADY="urn:uuid:9a04f079-9840-4286-ab92-e65be0885f95"

usage() {
    printf 'Usage:\n'
    printf '  %s manifest <channel> <manifest-url>\n' "$0"
    printf '  %s ytdlp <channel-page-url> [cookies.txt]\n' "$0"
    printf '  %s play <url>              # Pi only; DRM-free streams only\n' "$0"
    exit 1
}

find_ytdlp() {
    if [[ -n "${YTDLP}" && -x "${YTDLP}" ]]; then
        printf '%s' "${YTDLP}"
        return
    fi
    local candidate
    for candidate in \
        "${HOME}/egsob-decode/yt-dlp/yt-dlp_linux_aarch64" \
        "${HOME}/egsob-decode/yt-dlp/yt-dlp"
    do
        [[ -x "${candidate}" ]] && { printf '%s' "${candidate}"; return; }
    done
    if command -v yt-dlp > /dev/null 2>&1; then
        printf 'yt-dlp'
        return
    fi
    printf 'ERROR: yt-dlp not found; set YTDLP or run M0-12 fetch first.\n' >&2
    exit 1
}

detect_format() {
    local url="$1" file="$2"
    if grep -qE '^#EXTM3U' "${file}"; then
        printf 'hls'
    elif grep -qiE '<MPD' "${file}"; then
        printf 'dash'
    elif [[ "${url}" == *.m3u8* ]]; then
        printf 'hls'
    elif [[ "${url}" == *.mpd* ]]; then
        printf 'dash'
    else
        printf 'unknown'
    fi
}

hls_key_lines() {
    grep -E 'EXT-X-(SESSION-)?KEY' "$1" | grep -v 'METHOD=NONE' || true
}

hls_has_drm() {
    local keys
    keys=$(hls_key_lines "$1")
    if printf '%s' "${keys}" | grep -qE 'KEYFORMAT=|METHOD=SAMPLE-AES'; then
        printf 'yes'
    else
        printf 'no'
    fi
}

hls_first_variant() {
    local master_url="$1" master_file="$2"
    local rel
    rel=$(grep -A1 'EXT-X-STREAM-INF' "${master_file}" | grep -v '^#' | head -1 || true)
    [[ -z "${rel}" ]] && { printf ''; return; }
    [[ "${rel}" == http* ]] && { printf '%s' "${rel}"; return; }
    printf '%s/%s' "${master_url%/*}" "${rel}"
}

analyze_hls() {
    local channel="$1" url="$2" file="$3"
    local is_master='no' drm variant_url variant_file keys

    grep -q 'EXT-X-STREAM-INF' "${file}" && is_master='yes'
    drm=$(hls_has_drm "${file}")

    if [[ "${is_master}" == 'yes' && "${drm}" == 'no' ]]; then
        variant_url=$(hls_first_variant "${url}" "${file}")
        if [[ -n "${variant_url}" ]]; then
            variant_file="${EGSOB_AUVIO_DIR}/${channel}-variant.m3u8"
            curl -fsSL "${variant_url}" -o "${variant_file}" 2>/dev/null || true
            [[ -f "${variant_file}" ]] && drm=$(hls_has_drm "${variant_file}")
        fi
    fi

    printf 'FORMAT: hls\n'
    printf 'HLS master playlist: %s\n' "${is_master}"
    if [[ "${is_master}" == 'yes' ]]; then
        printf 'Streams (EXT-X-STREAM-INF):\n'
        grep 'EXT-X-STREAM-INF' "${file}" | sed 's/#EXT-X-STREAM-INF:/  /' || true
    fi
    keys=$(hls_key_lines "${file}")
    printf 'Key markers:\n'
    if [[ -n "${keys}" ]]; then
        printf '%s\n' "${keys}" | sed 's/^/  /'
    else
        printf '  (none)\n'
    fi
    printf 'DRM: %s\n' "${drm}"
}

dash_protection_entries() {
    grep -oE 'ContentProtection [^>]+>' "$1" | head -20 || true
}

dash_has_drm() {
    local entries
    entries=$(dash_protection_entries "$1")
    if [[ -z "${entries}" ]]; then
        printf 'no'
        return
    fi
    if printf '%s' "${entries}" | grep -qiE "${WIDEVINE}|${PLAYREADY}"; then
        printf 'yes'
        return
    fi
    # Any ContentProtection without a known scheme still signals DRM
    printf 'yes'
}

analyze_dash() {
    local file="$1"
    local entries drm
    entries=$(dash_protection_entries "${file}")
    drm=$(dash_has_drm "${file}")

    printf 'FORMAT: dash\n'
    printf 'ContentProtection entries:\n'
    if [[ -n "${entries}" ]]; then
        printf '%s\n' "${entries}" | sed 's/^/  /'
    else
        printf '  (none)\n'
    fi
    printf 'Video representations:\n'
    grep -oE 'width="[0-9]+" height="[0-9]+"' "${file}" \
        | sort -u | head -10 | sed 's/^/  /' || printf '  (not parsed)\n'
    printf 'DRM: %s\n' "${drm}"
}

run_manifest() {
    local channel="$1" url="$2"
    local raw="${EGSOB_AUVIO_DIR}/${channel}-manifest.raw"
    local report="${EGSOB_AUVIO_DIR}/${channel}-manifest.txt"

    printf 'Fetching manifest for %s ...\n' "${channel}"
    curl -fsSL "${url}" -o "${raw}"

    local fmt
    fmt=$(detect_format "${url}" "${raw}")

    {
        printf '=== %s manifest ===\n' "${channel}"
        case "${fmt}" in
            hls)  analyze_hls  "${channel}" "${url}" "${raw}" ;;
            dash) analyze_dash "${raw}" ;;
            *)    printf 'FORMAT: unknown\nDRM: unknown\n' ;;
        esac
    } | tee "${report}"

    printf '\nReport: %s\n' "${report}"
}

ytdlp_run_once() {
    local binary="$1" url="$2" label="$3"
    local fmts_file grabs_file rc
    fmts_file="${EGSOB_AUVIO_DIR}/${label}-formats.txt"
    grabs_file="${EGSOB_AUVIO_DIR}/${label}-urls.txt"
    shift 3

    printf '--- %s: formats ---\n' "${label}"
    rc=0
    "${binary}" -F "$@" "${url}" > "${fmts_file}" 2>&1 || rc=$?
    printf 'exit: %s\n' "${rc}" >> "${fmts_file}"
    cat "${fmts_file}"

    printf '--- %s: stream URLs (exit code only) ---\n' "${label}"
    rc=0
    "${binary}" -g "$@" "${url}" > "${grabs_file}" 2>&1 || rc=$?
    printf 'exit: %s\n' "${rc}" >> "${grabs_file}"
    printf 'exit: %s\n' "${rc}"
}

run_ytdlp() {
    local url="$1" cookies="${2:-}"
    local binary label
    binary=$(find_ytdlp)
    label=$(printf '%s' "${url}" | sed 's|.*rtbf\.be/||;s|[/?].*||' | cut -c1-24)
    [[ -z "${label}" ]] && label="channel"

    ytdlp_run_once "${binary}" "${url}" "${label}-nocookies"

    if [[ -n "${cookies}" ]]; then
        [[ -f "${cookies}" ]] || { printf 'ERROR: cookies file not found\n' >&2; exit 1; }
        printf '--- running again with cookies (path not logged) ---\n'
        ytdlp_run_once "${binary}" "${url}" "${label}-cookies" --cookies "${cookies}"
    fi
}

run_play() {
    local url="$1"
    local logfile
    logfile="${EGSOB_AUVIO_DIR}/play-$(date +%s).log"
    printf 'Playing 60 s  hwdec=%s  url=%s\n' "${HWDEC}" "${url}"
    timeout 60 mpv \
        --no-config --fs \
        "--hwdec=${HWDEC}" \
        --vo=gpu --gpu-context=drm \
        "--log-file=${logfile}" \
        "${url}" || true
    printf 'Done. Log: %s\n' "${logfile}"
}

main() {
    [[ $# -ge 1 ]] || usage
    mkdir -p "${EGSOB_AUVIO_DIR}"
    case "$1" in
        manifest)
            [[ $# -ge 3 ]] || { printf 'Usage: %s manifest <channel> <url>\n' "$0" >&2; exit 1; }
            run_manifest "$2" "$3"
            ;;
        ytdlp)
            [[ $# -ge 2 ]] || { printf 'Usage: %s ytdlp <page-url> [cookies.txt]\n' "$0" >&2; exit 1; }
            run_ytdlp "$2" "${3:-}"
            ;;
        play)
            [[ $# -ge 2 ]] || { printf 'Usage: %s play <url>\n' "$0" >&2; exit 1; }
            run_play "$2"
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
