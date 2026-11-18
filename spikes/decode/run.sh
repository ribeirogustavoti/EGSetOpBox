#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

EGSOB_DECODE_DIR="${EGSOB_DECODE_DIR:-${HOME}/egsob-decode}"

SAMPLE_NAMES=(h264-1080p hevc-1080p hevc-2160p vp9-1080p av1-1080p)
SAMPLE_URLS=(
    "https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_1080p_h264.mov"
    "https://repo.jellyfin.org/archive/jellyfish/media/jellyfish-20-mbps-hd-hevc.mkv"
    "https://repo.jellyfin.org/archive/jellyfish/media/jellyfish-120-mbps-4k-uhd-hevc-10bit.mkv"
    "https://upload.wikimedia.org/wikipedia/commons/transcoded/c/c0/Big_Buck_Bunny_4K.webm/Big_Buck_Bunny_4K.webm.1080p.vp9.webm"
    "local"
)
SAMPLE_EXTS=(mov mkv mkv webm mkv)

CHANNELS=(
    "https://www.youtube.com/@euronews/live"
    "https://www.youtube.com/@jovempannews/live"
    "https://www.youtube.com/@dwnews/live"
    "https://www.youtube.com/@RevistaOeste/live"
)

HWDEC_MODES=(no v4l2m2m-copy drm-copy v4l2m2m drm)
# 5 samples × 5 hwdec modes × 2 VO outputs (gpu-drm, drm)
TOTAL_FILE_RUNS=$(( ${#SAMPLE_NAMES[@]} * ${#HWDEC_MODES[@]} * 2 ))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_append_row() {
    # run sample hwdec_req vo hwdec_current frame_drops decoder_drops
    # video_codec est_fps mpv_exit log
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" \
        >> "${EGSOB_DECODE_DIR}/results.tsv"
}

_init_tsv() {
    local tsv="${EGSOB_DECODE_DIR}/results.tsv"
    if [[ ! -f "$tsv" ]]; then
        printf 'run\tsample\thwdec_req\tvo\thwdec_current\tframe_drops\tdecoder_drops\tvideo_codec\test_fps\tmpv_exit\tlog\n' \
            > "$tsv"
    fi
}

_next_run_n() {
    local tsv="${EGSOB_DECODE_DIR}/results.tsv"
    if [[ ! -f "$tsv" ]]; then
        printf '1'
    else
        printf '%d' "$(( $(tail -n +2 "$tsv" | wc -l) + 1 ))"
    fi
}

# Read one property from the mpv JSON IPC socket; prints "error" on failure.
_read_prop() {
    local sock="$1" prop="$2"
    printf '{"command":["get_property","%s"]}\n' "$prop" \
        | socat -t 2 - "UNIX-CONNECT:${sock}" 2>/dev/null \
        | jq -r '.data // "error"' 2>/dev/null \
        || printf 'error'
}

# ---------------------------------------------------------------------------
# Sub-commands
# ---------------------------------------------------------------------------

cmd_prepare_av1() {
    local src="${1:-}"
    if [[ -z "$src" ]]; then
        printf 'Usage: %s prepare-av1 <h264-file>\n' "$0" >&2; exit 1
    fi
    if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q 'libsvtav1'; then
        printf 'ERROR: ffmpeg does not have libsvtav1 (SVT-AV1 encoder not available).\n' >&2
        printf 'Install ffmpeg with SVT-AV1 support (e.g. from RPM Fusion on the dev host).\n' >&2
        exit 1
    fi
    mkdir -p "${EGSOB_DECODE_DIR}"
    local dst="${EGSOB_DECODE_DIR}/av1-1080p.mkv"
    ffmpeg -i "$src" -t 120 -c:v libsvtav1 -preset 8 -crf 35 -an "$dst"
    printf '\nCreated: %s\n' "$dst"
    printf 'Copy to Pi with:\n  scp %s <user>@egsob:%s/av1-1080p.mkv\n' \
        "$dst" "${EGSOB_DECODE_DIR}"
}

cmd_fetch() {
    mkdir -p "${EGSOB_DECODE_DIR}"
    local i name url ext file
    for i in "${!SAMPLE_NAMES[@]}"; do
        name="${SAMPLE_NAMES[$i]}"
        url="${SAMPLE_URLS[$i]}"
        ext="${SAMPLE_EXTS[$i]}"
        file="${EGSOB_DECODE_DIR}/${name}.${ext}"
        if [[ "$url" == "local" ]]; then
            printf 'SKIP %s: local file — copy av1-1080p.mkv from the dev host first.\n' "$name"
            continue
        fi
        printf '\nFetching %s ...\n' "$name"
        curl -fL -C - -o "$file" "$url"
        printf 'Probe %s:\n' "$name"
        ffprobe -v error -select_streams v:0 \
            -show_entries 'stream=codec_name,width,height,pix_fmt,bit_rate' \
            -of default "$file" 2>&1 || true
        printf '  size on disk: %s\n' "$(du -sh "$file" | cut -f1)"
    done
}

cmd_files() {
    if [[ $(id -u) -ne 0 ]]; then
        printf 'ERROR: "files" must run as root (DRM master required):\n' >&2
        printf '  sudo %s files\n' "$0" >&2
        exit 1
    fi

    local dir="${EGSOB_DECODE_DIR}"
    mkdir -p "${dir}/logs"
    _init_tsv

    local i name ext sample_file hwdec vo_label
    local sock log mpv_pid mpv_exit waited
    local hwdec_current frame_drops dec_drops video_codec est_fps
    local vo_args run_n=0

    for i in "${!SAMPLE_NAMES[@]}"; do
        name="${SAMPLE_NAMES[$i]}"
        ext="${SAMPLE_EXTS[$i]}"
        sample_file="${dir}/${name}.${ext}"

        for hwdec in "${HWDEC_MODES[@]}"; do
            for vo_label in gpu-drm drm; do
                run_n=$(( run_n + 1 ))

                if [[ ! -f "$sample_file" ]]; then
                    printf 'RUN %d/%d: %s — file missing, row recorded\n' \
                        "$run_n" "$TOTAL_FILE_RUNS" "$name"
                    _append_row "$run_n" "$name" "$hwdec" "$vo_label" \
                        "" "" "" "" "" "skip-missing" ""
                    continue
                fi

                printf 'RUN %d/%d: %s  hwdec=%s  vo=%s\n' \
                    "$run_n" "$TOTAL_FILE_RUNS" "$name" "$hwdec" "$vo_label"

                sock="${dir}/mpv-${run_n}.sock"
                log="${dir}/logs/run-$(printf '%03d' "$run_n")-${name}-${hwdec}-${vo_label}.log"
                rm -f "$sock"

                if [[ "$vo_label" == "gpu-drm" ]]; then
                    vo_args=(--vo=gpu --gpu-context=drm)
                else
                    vo_args=(--vo=drm)
                fi

                mpv_exit=0
                mpv --no-config --fs \
                    "--length=60" \
                    "--drm-mode=3840x2160@30" \
                    "--hwdec=${hwdec}" \
                    "${vo_args[@]}" \
                    "--osd-level=1" \
                    "--osd-msg1=run ${run_n}/${TOTAL_FILE_RUNS} ${name} ${hwdec} ${vo_label}" \
                    "--input-ipc-server=${sock}" \
                    "--log-file=${log}" \
                    "$sample_file" &
                mpv_pid=$!

                # Wait up to 10 s for the IPC socket to appear
                waited=0
                while [[ ! -S "$sock" && $waited -lt 10 ]]; do
                    sleep 1
                    waited=$(( waited + 1 ))
                done

                # Sleep until ~5 s before the 60 s mark
                sleep 50

                hwdec_current=$(_read_prop "$sock" hwdec-current)
                frame_drops=$(_read_prop "$sock" frame-drop-count)
                dec_drops=$(_read_prop "$sock" decoder-frame-drop-count)
                video_codec=$(_read_prop "$sock" video-codec)
                est_fps=$(_read_prop "$sock" estimated-vf-fps)

                wait "$mpv_pid" || mpv_exit=$?
                rm -f "$sock"

                _append_row "$run_n" "$name" "$hwdec" "$vo_label" \
                    "$hwdec_current" "$frame_drops" "$dec_drops" \
                    "$video_codec" "$est_fps" "$mpv_exit" "$(basename "$log")"
            done
        done
    done

    printf '\nAll %d runs complete. Results: %s/results.tsv\n' \
        "$run_n" "$dir"
}

cmd_youtube() {
    local dir="${EGSOB_DECODE_DIR}"
    local ytdlp_dir="${dir}/yt-dlp"
    local ytdlp_bin="${ytdlp_dir}/yt-dlp_linux_aarch64"

    mkdir -p "${dir}/logs" "$ytdlp_dir"
    _init_tsv

    # Download latest stable yt-dlp binary and verify its checksum
    printf 'Fetching yt-dlp release metadata from GitHub...\n'
    local release_json binary_url sums_url
    release_json=$(curl -fsSL 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest')
    binary_url=$(printf '%s' "$release_json" | jq -r \
        '.assets[] | select(.name == "yt-dlp_linux_aarch64") | .browser_download_url')
    sums_url=$(printf '%s' "$release_json" | jq -r \
        '.assets[] | select(.name == "SHA2-256SUMS") | .browser_download_url')

    printf 'Downloading yt-dlp_linux_aarch64...\n'
    curl -fL -o "$ytdlp_bin" "$binary_url"
    printf 'Downloading SHA2-256SUMS...\n'
    curl -fL -o "${ytdlp_dir}/SHA2-256SUMS" "$sums_url"

    local expected_sha actual_sha
    expected_sha=$(grep 'yt-dlp_linux_aarch64' "${ytdlp_dir}/SHA2-256SUMS" | awk '{print $1}')
    actual_sha=$(sha256sum "$ytdlp_bin" | awk '{print $1}')
    if [[ "$expected_sha" != "$actual_sha" ]]; then
        printf 'ERROR: SHA256 mismatch\n  expected: %s\n  actual:   %s\n' \
            "$expected_sha" "$actual_sha" >&2
        exit 1
    fi
    printf 'SHA256 OK: %s\n' "$actual_sha"
    chmod +x "$ytdlp_bin"
    printf 'yt-dlp version: %s\n' "$("$ytdlp_bin" --version)"

    local run_n
    run_n=$(_next_run_n)

    local channel_url channel_name sock log mpv_exit
    local hwdec_current frame_drops dec_drops video_codec est_fps
    local mpv_pid waited hwdec formats_file

    for channel_url in "${CHANNELS[@]}"; do
        channel_name=$(printf '%s' "$channel_url" | grep -o '@[^/]*' | tr -d '@')
        printf '\n=== Channel: %s ===\n' "$channel_name"

        formats_file="${dir}/${channel_name}-formats.txt"
        printf 'yt-dlp -F %s\n' "$channel_url"
        if ! "$ytdlp_bin" -F "$channel_url" > "$formats_file" 2>&1; then
            printf '  Channel not live or yt-dlp error; recording rows as not-live.\n'
            cat "$formats_file" || true
            for hwdec in no v4l2m2m-copy; do
                _append_row "$run_n" "$channel_name" "$hwdec" "gpu-drm" \
                    "not-live" "" "" "" "" "ytdlp-fail" ""
                run_n=$(( run_n + 1 ))
            done
            continue
        fi
        cat "$formats_file"

        for hwdec in no v4l2m2m-copy; do
            printf '\nRUN yt/%d: %s  hwdec=%s\n' "$run_n" "$channel_name" "$hwdec"

            sock="${dir}/mpv-yt-${channel_name}-${hwdec}.sock"
            log="${dir}/logs/run-yt-${channel_name}-${hwdec}.log"
            rm -f "$sock"

            mpv_exit=0
            mpv --no-config --fs \
                "--length=60" \
                "--drm-mode=3840x2160@30" \
                "--hwdec=${hwdec}" \
                --vo=gpu --gpu-context=drm \
                "--script-opts=ytdl_hook-ytdl_path=${ytdlp_bin}" \
                "--ytdl-format=bestvideo[vcodec^=avc1][height<=1080]+bestaudio/best[vcodec^=avc1][height<=1080]" \
                "--input-ipc-server=${sock}" \
                "--log-file=${log}" \
                "$channel_url" &
            mpv_pid=$!

            waited=0
            while [[ ! -S "$sock" && $waited -lt 15 ]]; do
                sleep 1
                waited=$(( waited + 1 ))
            done
            sleep 50

            hwdec_current=$(_read_prop "$sock" hwdec-current)
            frame_drops=$(_read_prop "$sock" frame-drop-count)
            dec_drops=$(_read_prop "$sock" decoder-frame-drop-count)
            video_codec=$(_read_prop "$sock" video-codec)
            est_fps=$(_read_prop "$sock" estimated-vf-fps)

            wait "$mpv_pid" || mpv_exit=$?
            rm -f "$sock"

            _append_row "$run_n" "$channel_name" "$hwdec" "gpu-drm" \
                "$hwdec_current" "$frame_drops" "$dec_drops" \
                "$video_codec" "$est_fps" "$mpv_exit" "$(basename "$log")"
            run_n=$(( run_n + 1 ))
        done
    done

    printf '\nYouTube runs complete. Results: %s/results.tsv\n' "$dir"
}

# ---------------------------------------------------------------------------

case "${1:-}" in
    prepare-av1) cmd_prepare_av1 "${@:2}" ;;
    fetch)       cmd_fetch ;;
    files)       cmd_files ;;
    youtube)     cmd_youtube ;;
    *)
        printf 'Usage: %s {prepare-av1 <h264-file>|fetch|files|youtube}\n\n' "$0" >&2
        printf '  prepare-av1 <h264-file>  Encode a 120-s AV1 sample (run on the dev host)\n' >&2
        printf '  fetch                    Download all sample files (run on the Pi)\n' >&2
        printf '  files                    Run all hwdec/vo combinations (run on the Pi as root)\n' >&2
        printf '  youtube                  Fetch yt-dlp and play the four YouTube lives (run on the Pi)\n' >&2
        exit 1
        ;;
esac
