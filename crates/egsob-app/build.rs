// SPDX-License-Identifier: GPL-3.0-only
//! Build script: embeds the git short hash and the UTC build time (Chat Master D-118).

use std::path::Path;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

const UNKNOWN: &str = "unknown";
const HASH_LEN: usize = 7;

fn main() {
    rerun_on_git_changes();
    println!("cargo:rerun-if-env-changed=SOURCE_DATE_EPOCH");
    println!("cargo:rustc-env=EGSOB_GIT_HASH={}", git_hash());
    println!("cargo:rustc-env=EGSOB_BUILD_TIME={}", build_time());
}

/// Runs `git` with `args` and returns its trimmed stdout, or `None` on any failure.
fn git(args: &[&str]) -> Option<String> {
    let output = Command::new("git").args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8(output.stdout).ok()?;
    Some(text.trim().to_owned())
}

/// Re-runs this script when `HEAD`, the current branch ref or `packed-refs` change.
fn rerun_on_git_changes() {
    println!("cargo:rerun-if-changed=build.rs");
    let mut names = vec!["HEAD".to_owned(), "packed-refs".to_owned()];
    if let Some(branch) = git(&["symbolic-ref", "-q", "HEAD"]) {
        names.push(branch);
    }
    for name in names {
        if let Some(path) = git(&["rev-parse", "--git-path", &name])
            && Path::new(&path).exists()
        {
            println!("cargo:rerun-if-changed={path}");
        }
    }
}

/// First 7 hex digits of `HEAD`, `-dirty` when tracked files have changes, else `unknown`.
fn git_hash() -> String {
    let Some(full) = git(&["rev-parse", "HEAD"]) else {
        return UNKNOWN.to_owned();
    };
    let Some(short) = full.get(..HASH_LEN) else {
        return UNKNOWN.to_owned();
    };
    match git(&["status", "--porcelain", "--untracked-files=no"]) {
        Some(changes) if changes.is_empty() => short.to_owned(),
        Some(_) => format!("{short}-dirty"),
        None => UNKNOWN.to_owned(),
    }
}

/// Build time as `YYYY-MM-DD HH:MM UTC`; `SOURCE_DATE_EPOCH` wins over the clock.
fn build_time() -> String {
    epoch_seconds().map_or_else(|| UNKNOWN.to_owned(), format_utc)
}

fn epoch_seconds() -> Option<u64> {
    if let Ok(value) = std::env::var("SOURCE_DATE_EPOCH") {
        return value.trim().parse().ok();
    }
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .ok()
        .map(|elapsed| elapsed.as_secs())
}

fn format_utc(seconds: u64) -> String {
    let (year, month, day) = civil_from_days(seconds / 86_400);
    let hour = seconds % 86_400 / 3_600;
    let minute = seconds % 3_600 / 60;
    format!("{year:04}-{month:02}-{day:02} {hour:02}:{minute:02} UTC")
}

/// Days since 1970-01-01 to (year, month, day), Howard Hinnant's `civil_from_days`.
fn civil_from_days(days: u64) -> (u64, u64, u64) {
    let shifted = days + 719_468;
    let era = shifted / 146_097;
    let day_of_era = shifted - era * 146_097;
    let year_of_era =
        (day_of_era - day_of_era / 1_460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_index = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * month_index + 2) / 5 + 1;
    let month = if month_index < 10 {
        month_index + 3
    } else {
        month_index - 9
    };
    let year = era * 400 + year_of_era + u64::from(month <= 2);
    (year, month, day)
}
