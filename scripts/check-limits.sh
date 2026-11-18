#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Code limits gate (EGSetOpBox-Code-Master.md, CODE LIMITS).
# Checks every tracked .rs, .js and .slint file:
#   1. at most 300 code lines per file (tokei),
#   2. cyclomatic complexity at most 15 per function in .rs/.js (lizard),
#   3. no inline #[cfg(test)] modules in .rs files,
#   4. no suppression of the complexity checks.
# Exits 1 and prints every violation if any check fails.

set -euo pipefail

readonly MAX_CODE_LINES=300
readonly MAX_CCN=15

failed=0

fail() {
    echo "FAIL $*"
    failed=1
}

require_tools() {
    local tool
    for tool in git jq tokei lizard; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "check-limits: required tool '$tool' not found" >&2
            exit 2
        fi
    done
}

check_file_size() {
    local -a files=("$@")
    local counted code name file
    counted="$(tokei --output json -- "${files[@]}" |
        jq -r 'to_entries[] | .value.reports[]? | "\(.stats.code)\t\(.name)"' |
        sed 's#\t\./#\t#')"
    while IFS=$'\t' read -r code name; do
        [[ -z "$name" ]] && continue
        if ((code > MAX_CODE_LINES)); then
            fail "size: $name has $code code lines (max $MAX_CODE_LINES)"
        fi
    done <<<"$counted"
    for file in "${files[@]}"; do
        if ! grep -qF -- "$(printf '\t%s' "$file")" <<<"$counted"; then
            fail "size: $file was not counted by tokei"
        fi
    done
}

check_complexity() {
    local -a files=("$@")
    local warnings
    ((${#files[@]} == 0)) && return 0
    warnings="$(lizard -l rust -l javascript -C "$MAX_CCN" -w -- "${files[@]}" || true)"
    if grep -q ': warning:' <<<"$warnings"; then
        while IFS= read -r line; do
            fail "complexity: $line"
        done < <(grep ': warning:' <<<"$warnings")
    fi
}

check_inline_tests() {
    local -a files=("$@")
    local hit
    ((${#files[@]} == 0)) && return 0
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && fail "inline test module: $hit"
    done < <(awk '
        FNR == 1 { prev = "" }
        /#\[cfg\(test\)\][[:space:]]*(pub(\([a-z]+\))?[[:space:]]+)?mod[[:space:]]+[A-Za-z0-9_]+[[:space:]]*\{/ {
            print FILENAME ":" FNR
        }
        /^[[:space:]]*$/ { next }
        {
            if (prev ~ /^[[:space:]]*#\[cfg\(test\)\][[:space:]]*$/ &&
                $0 ~ /^[[:space:]]*(pub(\([a-z]+\))?[[:space:]]+)?mod[[:space:]]+[A-Za-z0-9_]+[[:space:]]*\{/) {
                print FILENAME ":" FNR
            }
            prev = $0
        }' "${files[@]}")
}

check_suppressions() {
    local -a files=("$@")
    local hit
    while IFS= read -r hit; do
        [[ -n "$hit" ]] && fail "suppressed complexity check: $hit"
    done < <(grep -nE 'lizard forgives|(allow|expect)\(clippy::cognitive_complexity' -- "${files[@]}" || true)
}

main() {
    require_tools
    cd "$(git rev-parse --show-toplevel)"

    local -a all_files code_files rust_files
    mapfile -t all_files < <(git ls-files -- '*.rs' '*.js' '*.slint')
    if ((${#all_files[@]} == 0)); then
        echo "check-limits: no .rs/.js/.slint files"
        exit 0
    fi
    mapfile -t code_files < <(printf '%s\n' "${all_files[@]}" | grep -E '\.(rs|js)$' || true)
    mapfile -t rust_files < <(printf '%s\n' "${all_files[@]}" | grep -E '\.rs$' || true)

    check_file_size "${all_files[@]}"
    check_complexity "${code_files[@]}"
    check_inline_tests "${rust_files[@]}"
    check_suppressions "${all_files[@]}"

    if ((failed)); then
        echo "check-limits: FAILED"
        exit 1
    fi
    echo "check-limits: OK (${#all_files[@]} files)"
}

main "$@"
