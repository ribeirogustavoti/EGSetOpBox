# EGSetOpBox — Master Prompt (Chat / Project Decisions) — Source of Truth

> **What this file is.** The canonical record of what EGSetOpBox is, every design decision taken so far, the architecture, the milestone/epic/feature backlog, open decisions, and the system prompt for planning chats.
>
> **What this file is NOT.** Issue-format rules live only in `EGSetOpBox-Issue-Master.md`. AI-agent execution rules live only in `EGSetOpBox-Code-Master.md`. This file carries **pointers** to them and never restates their rules.
>
> **Session start.** Every new planning session loads this file, plus `EGSetOpBox-Issue-Master.md` when an issue will be drafted. Decisions here are binding until changed here (with a §11 change log entry).

---

## 1. Project summary

EGSetOpBox is a personal, single-user TV set-top box built on a **Raspberry Pi 4B (4 GB)** connected by HDMI to a **Sony Bravia 4K TV**. It runs a **custom Fedora image built with KIWI NG** and a **Rust application** that provides a 10-foot interface (inspired by Kodi, Stremio, Pluto TV and Samsung TV Plus) to:

- Watch **live channels** (EuroNews, RTBF Auvio, Jovem Pan News, Revista Oeste, Fox News, DW…) — every channel is an **add-on** that can be installed or removed at will.
- Browse and watch **movies, series, documentaries and TV shows** with Stremio-like catalogs and stream sources, including a **generic torrent streaming engine**.
- Fetch **subtitles from OpenSubtitles**.
- Be controlled by the **Bravia remote (HDMI-CEC)**, **keyboard**, **mouse**, and a **phone web remote**.

Private use only; it is not distributed to other users. Repository is **public on GitHub under GPL-3.0-only**.

---

## 2. Engineering persona for planning chats

Act as a senior software engineer experienced in embedded Linux, TV/set-top-box software and Rust. Ask, don't guess: when a decision is not recorded in §3, present the options as a pick-list (with a free-text "Other") and record the answer here before building on it.

---

## 3. Decision record

| # | Topic | Decision |
|---|---|---|
| D-01 | Hardware | Raspberry Pi 4B, **4 GB RAM**, **microSD** boot/storage, **Ethernet and Wi-Fi** both supported. |
| D-02 | TV | Sony Bravia, **4K (3840×2160)**. Video target: **1080p H.264**, software fallback; HEVC/4K only when the kernel supports Pi HEVC decode. |
| D-03 | OS | Fedora-based, **custom image built with KIWI NG**. Release policy: **pin N-1** → **Fedora 44** (Fedora 45 released 2026-11-03). F44 support ends about one month after Fedora 46 is released; plan the move to the next N-1 then. |
| D-04 | OS limits | Accept Fedora's limited Pi video acceleration; no custom kernel. |
| D-05 | Codecs | **RPM Fusion free** enabled in the image (full ffmpeg/libavcodec for mpv). |
| D-06 | Updates | No field deployment. The box is updated with **`dnf upgrade`** over the network. App RPMs come from **Fedora COPR**. |
| D-07 | Player | **libmpv**. |
| D-08 | UI toolkit | **Slint**, used under **GPLv3** (its royalty-free licence excludes embedded systems). |
| D-09 | Display path | **Direct KMS/DRM**, no compositor. |
| D-10 | Licence | **Whole project GPL-3.0-only**. SPDX header on every source file. |
| D-11 | Torrents | **Generic torrent engine** in the core (content sources are the user's responsibility); engine **librqbit**, **RAM cache** (bounded; size in settings). No disk cache on the microSD. |
| D-12 | API host | All APIs run **locally on the Pi**. |
| D-13 | API stack | **Rust + axum**. |
| D-14 | Add-on model | **Kodi-like packages without Python**: folder or archive with `manifest.toml`, installable/removable/enable-disable from the UI. Capabilities: `channel`, `catalog`, `stream`, `subtitles`, plus a **Stremio-bridge** kind pointing to a Stremio-compatible HTTP endpoint. Add-ons return *what* to play; the core owns *how* (mpv, torrent engine, resolvers). |
| D-15 | Add-on scripting | **Rhai** embedded runtime for add-ons that need logic. Simple channels are manifest-only. |
| D-16 | Add-on distribution | Separate GitHub repository (**`EGSetOpBox-addons`**) with an `index.json`; the box checks it for updates. |
| D-17 | Channel types | `youtube`, `hls`, `dash`, `direct`, each optionally with a Rhai resolver that obtains the current URL **at play time**. |
| D-18 | Stable references | Never store final stream URLs; store stable identities (YouTube channel ID/handle, broadcaster page/API endpoint) and resolve on Play. |
| D-19 | YouTube | **yt-dlp** resolves at play time (through mpv / the resolver); the box keeps **its own yt-dlp copy and self-updates it** on a schedule. **YouTube Data API is optional** (later add-on for search/listing). |
| D-20 | DRM | Widevine/other DRM is **not supported and never circumvented**. The resolver detects DRM in HLS/DASH manifests and the UI shows "DRM-protected – not playable". Early spike checks RTBF Auvio live channels. |
| D-21 | Database | **SQLite via rusqlite**. |
| D-22 | Secrets | **Encrypted in the database** (AEAD, e.g. XChaCha20-Poly1305) with a key file readable only by the service user. |
| D-23 | Profiles | **Single user**. |
| D-24 | Inputs | **HDMI-CEC via the kernel CEC API directly** (`/dev/cec0`, no libcec), keyboard, mouse, **phone web remote**. |
| D-25 | Phone remote auth | **Pairing PIN shown on the TV**; phone stores a token. |
| D-26 | UI style | **Hybrid**: left menu (Kodi-like) + poster rows (Stremio) + live TV guide grid (Pluto/Samsung). |
| D-27 | Live TV features | **EPG guide grid** (when the source provides data), **channel numbers + CH+/CH− zapping**, **favourites and groups**. (Auto-play last channel at boot: **not** selected.) |
| D-28 | VOD metadata | **TMDB** (API key stored as a secret). |
| D-29 | Languages | UI: **English (default)**, Portuguese (BR), French, Dutch. Subtitle auto-selection order: **pt-BR > en > fr > nl**. |
| D-30 | Issue format | See `EGSetOpBox-Issue-Master.md` (canonical; no labels). |
| D-31 | AI agents | Claude Code or GitHub Copilot; execution rules in `EGSetOpBox-Code-Master.md`. |
| D-32 | Assignee | `ribeirogustavoti`. |
| D-33 | Git workflow | **Branch + PR per issue**: branch `issue-<n>-<slug>`, PR body `Closes #<n>`, **squash merge** to `main`. |
| D-34 | PR gate | `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test --workspace`, **code limits check** (≤300 code lines per `.rs`/`.js` file, cyclomatic and cognitive complexity ≤15, tests in separate files — rules in `EGSetOpBox-Code-Master.md`, CODE LIMITS), **VM smoke test** (D-51). |
| D-35 | Dev host | **x86_64 Fedora** workstation with KVM/QEMU. |
| D-36 | Builds | **GitHub Actions arm64 runners** for CI builds (gate, test RPM, KIWI image). Release RPMs are built and published by **COPR** (D-06). |
| D-37 | Logging | **tracing → journald** (`journalctl -u egsob`), log level in settings. |
| D-38 | Crate prefix | **`egsob-*`**. |
| D-39 | Master files | Three files at the **repo root**: `EGSetOpBox-Chat-Master.md`, `EGSetOpBox-Code-Master.md`, `EGSetOpBox-Issue-Master.md`. |
| D-40 | Subtitles | OpenSubtitles **REST API** (`api.opensubtitles.com`), API key + optional account as secrets; respect daily download quota. |
| D-41 | Milestones | M0–M9 as listed in §8 (approved). |
| D-42 | Process model | **Single binary** `egsob`: UI, libmpv, add-ons, resolver, torrent and axum API in one process. (UI and video must share one process anyway: separate processes contending for DRM caused frame drops on Pi 4 in other projects.) |
| D-43 | Slint renderer | **FemtoVG** (OpenGL ES 2.0) on the **LinuxKMS** backend; libmpv renders through the libmpv OpenGL render API into the same GL context. |
| D-44 | Rust toolchain | **Edition 2024**. MSRV = the **rustc version shipped in Fedora 44** repos (COPR builds with it); pinned in `rust-toolchain.toml` and checked in CI. |
| D-45 | Device access | **libseat via systemd-logind**: `egsob.service` runs as user `egsob` with a logind session on tty1 (`PAMName`/`TTYPath`), no root. Slint built with libseat + libinput. `/dev/cec0` reached through a udev rule. M0 spike must confirm logind activates the session (known Fedora kiosk pitfall: "Could not activate session: Permission denied"). |
| D-46 | Rhai host API (api = 1) | **Minimal + HTML**: `http_get`/`http_post` with headers, JSON, regex, HTML parsing with CSS selectors, logging, return `StreamRef`. No cookies (possible later as `api = 2`). Always-on limits: max operations, call depth, expression depth, string/array/map sizes, per-call wall-clock timeout, `eval` and `import` disabled, per-add-on network allowlist (`net_allow`). |
| D-47 | EPG sources | **Both**: a GitHub Action in `EGSetOpBox-addons` runs the iptv-org/epg grabber for the installed channels and publishes `guide.xml` (default); a channel add-on may override it with its own XMLTV URL + channel id. The core only downloads and parses XMLTV (no grabber on the box). Channels without data show name only. |
| D-48 | Add-on integrity | **sha256 only** (in `index.json`, fetched over HTTPS from GitHub). No signatures. |
| D-49 | yt-dlp | Official **`yt-dlp_linux_aarch64`** standalone binary, **stable** channel, in `/var/lib/egsob/yt-dlp/`. Update = **verified swap**: download → check against SHA2-256SUMS → self-test (`--version` + resolve one known YouTube live) → atomic swap, previous version kept for automatic rollback. Runs **at boot and daily** (systemd timer). |
| D-50 | RTBF Auvio | Settled by the **M0 spike**, tested from the Brussels connection, for La Une, Tipik and La Trois live. It checks: (a) DRM present? (b) login required? (c) plain HLS/DASH? If DRM → RTBF add-on uses RTBF's YouTube channels. If no DRM but login required → extend the Rhai host API with a per-add-on cookie jar as **`api = 2`** (amends D-46), Auvio credentials stored as encrypted secrets (D-22). |
| D-51 | VM smoke test | **Scripted + checklist.** A `vm/` script boots the x86_64 KVM VM, starts `egsob`, sends remote keys via `cec-ctl` on the `vivid` CEC device, checks `journalctl -u egsob` for expected events and errors, and saves a QEMU `screendump` screenshot. Each issue's AC adds a short manual checklist of what must be seen. **Run by the engineer** during PR review (not by the AI agent). Video quality is judged only on the Pi. |
| D-52 | Repository | `ribeirogustavoti/EGSetOpBox`, public. Engineer creates it empty; settings: default branch `main`, **squash merge only**, delete branch on merge. **No branch protection** on `main`. |
| D-53 | Epics | Tracked **only in §8**. GitHub issues carry the milestone only (no epic issues, no Project board). |
| D-54 | M0 agent | **Claude Code** implements every M0 issue. |
| D-55 | Workspace scaffold | **All 12 `egsob-*` crates** are scaffolded in one issue (one-off cap waiver, Issue Master §5.3). |
| D-56 | Toolchain use | **rustup everywhere** (dev host and CI), driven by `rust-toolchain.toml` pinned to the Fedora 44 rustc version (D-44). |
| D-57 | Binary | Crate `egsob-app` builds the binary via `[[bin]] name = "egsob"`. |
| D-58 | Lints and format | Workspace lints: `clippy::cognitive_complexity` (threshold 15), **`clippy::pedantic` warn**, **`clippy::unwrap_used` and `clippy::expect_used` deny** outside tests, **`unsafe_code` deny** (FFI crates opt in at crate level). `rustfmt.toml` holds `edition = "2024"` only. |
| D-59 | Code limits tooling | Bash script **`scripts/check-limits.sh`**. `tokei` and `lizard` (D-78) come from **Fedora RPMs where packaged**, otherwise a pinned upstream install (`cargo install --locked`, or `pip` for lizard, D-78). The 300-code-line limit also covers **`.slint`** files. |
| D-60 | CI runner | GitHub-hosted **`ubuntu-24.04-arm`** running a **`fedora:44` container**; **arm64 only**. **shellcheck** runs on every `.sh` file in the PR gate. |
| D-61 | COPR | Build from git with **SCM + `make_srpm`** (`.copr/Makefile`). **Networking enabled** in the COPR project (no crate vendoring); `Cargo.lock` committed. Chroot **`fedora-44-aarch64` only**. Builds on **version tags** only. |
| D-62 | Versioning | **SemVer 0.x**, one version for workspace, RPM and image; tags `vX.Y.Z`. |
| D-63 | Service user | `egsob` is created **both** by an RPM `sysusers.d` file and in KIWI `config.sh`. |
| D-64 | Service restart | `egsob.service`: `Restart=always`, `RestartSec=2`. |
| D-65 | KIWI builds | Pi image (aarch64) built in **CI on tag** and published as a **GitHub Release asset** (`.raw.xz`); the dev host can also build it (aarch64 via qemu-user-static). An **x86_64 profile** of the same description, built **on the dev host only**, is the smoke-test VM image. |
| D-66 | Image contents | Boot chain = **Fedora default** (Pi firmware → U-Boot → UEFI → GRUB). Root FS **btrfs**. `en_US.UTF-8`, `Europe/Brussels`, hostname `egsob`. **sshd on, key-only**; the engineer's public key is committed in `os/kiwi/`. **Wi-Fi is configured after first boot** (Ethernet + SSH + `nmcli`); credentials are never in the image. |
| D-67 | Audio | **ALSA direct** (mpv `ao=alsa`) to HDMI; no sound server. |
| D-68 | Display | Bravia on **HDMI0** (`/dev/cec0` expected). KMS output **3840×2160@30**; video stays 1080p (D-02) and is scaled. |
| D-69 | VMs | x86_64 VM: KIWI x86_64 profile, **`virtio-vga-gl` + virgl**, `-display egl-headless`; `egsob` is **built on the dev host and shared** into the VM (virtiofs/9p). aarch64 VM: QEMU **`virt` + edk2 UEFI** (userspace/RPM checks, not Pi firmware boot). Scripts are **Bash + shellcheck**. |
| D-70 | Spikes | Format per Issue Master §5.4. Agent writes the code; **engineer runs it** on the Pi, which runs the **stock Fedora 44 aarch64** image until the KIWI image exists. **Two PRs per spike:** the code PR is closed unmerged (branch kept); the findings PR merges `docs/spikes/<name>.md` and the Chat Master update. Slint spike uses the **`libmpv2` crate**; must show 1080p H.264 with ~0 dropped frames, UI ≥30 fps over video at 4K30, and running as `egsob` via logind on tty1 without root (D-45). Decode spike: public sample files fetched by its script. CEC spike keys: D-pad/OK/Back, Play/Pause/Stop/FF/RW, CH+/CH−, digits. Auvio spike: run by the engineer with his own account; credentials never committed. |
| D-71 | M0 exit | All M0 items closed; the Pi boots the KIWI image and `egsob.service` shows the **placeholder screen** on the Bravia; spike findings recorded (O-04 resolved, D-50 settled, CEC and Slint findings in §3); tag `v0.1.0` builds in COPR and `dnf upgrade` on the Pi pulls it. **No due date.** |
| D-72 | README | Summary + GPL-3.0-only + private-use note; pointers to the three masters; legal note (content-agnostic torrent/Stremio, no DRM circumvention); a **Build** section filled by the workspace scaffold issue. |
| D-73 | Claude Code config | Repo root `CLAUDE.md` points the agent to the three masters and restates the no-attribution rule; `.claude/settings.json` sets `"attribution": {"commit": "", "pr": ""}` so Claude Code adds no trailer or PR footer. |
| D-74 | Planning sessions | Planning chats draft the milestone and its issues **and create them on GitHub**, and the issues must be correct when the session ends; the engineer does no clean-up. Any session that writes to GitHub runs in **Claude Code on the dev host** with the engineer's own `gh` login and attribution off (`~/.claude/settings.json` and D-73). Cloud sessions that add attribution to GitHub writes never write to GitHub. Drafts are delivered as **body-only files**; title, milestone and assignee are given separately. No automated attribution check. |
| D-75 | Cargo.lock | Committed. Issues list it in Where as `(NEW — generated by cargo)` or `(MODIFY — generated by cargo)`; it needs no Source Code Sample. |
| D-76 | Scaffold details | Workspace version **0.1.0**. Until M0-20, `egsob` prints `egsob <version>`. Dependencies follow §4.1: `egsob-app` → `egsob-core` → the 10 service crates, declared as path entries in `[workspace.dependencies]`. Every crate has `[lints] workspace = true` (the root carries `[workspace.lints]`), an SPDX line plus a `//!` doc line, and the same text as its Cargo `description`; `publish = false`. `.gitignore` (`/target`) comes with the scaffold. |
| D-77 | Toolchain pin | `rust-toolchain.toml` holds the **exact** version of Fedora 44's `rust` package (updates repo). The CI check (M0-08) **fails** when they differ; the engineer bumps the pin through a small issue. Refines D-44 and D-56. |
| D-78 | Cyclomatic tool | **lizard** measures per-function cyclomatic complexity for `.rs` and `.js` (replaces `rust-code-analysis-cli`, which is not packaged in Fedora and has had no release for about 3 years). Not packaged in Fedora 44: installed with **`pip install --user lizard==1.23.0`** on the dev host and in CI. `lizard forgives` suppression comments are forbidden; the limits script fails on them. |
| D-79 | GitHub Actions | Actions referenced by **major tag** (`actions/checkout@v6`, `actions/cache@v6`); cargo registry and `target/` cached. |
| D-80 | Drafting waves | M0 bodies are drafted per phase: Phase A first, each later phase once the previous one is merged. Each wave starts with a `Docs — record <wave> planning decisions` issue. Issues are created on GitHub by a Claude Code prompt run on the dev host (D-74). |
| D-81 | Issue #1 | Pushed directly to `main` without a PR, because the repo had no `main` branch yet. One-off exception to D-33. |
| D-82 | Dev host release | The dev host currently runs **Fedora 37** (end of life). The engineer upgrades it to **Fedora 44** before M0-06 (D-84); D-35 means Fedora 44 from then on. |
| D-83 | Pre-VM runtime checks | Until M0-19 (smoke test script) is merged, issues that change runtime behaviour replace the VM smoke test AC line with a command check (e.g. `cargo run -p egsob-app` prints `egsob 0.1.0`). |
| D-84 | Wave A sequencing | The dev host is upgraded to Fedora 44 **before M0-06** is dispatched; M0-30 and M0-02…M0-05 run on the current host with rustup. |
| D-85 | MSRV | The workspace sets `rust-version = "1.99.1"` (same value as `rust-toolchain.toml`, D-77) and every crate inherits it; set in the scaffold (M0-02). |
| D-86 | CI runs | The CI workflow runs on **pull requests to `main`** and **pushes to `main`**. A CI issue is accepted when its own PR run is green. |
| D-87 | SPDX on config | Every TOML and YAML file (Cargo manifests, toolchain/rustfmt/clippy config, GitHub workflows, KIWI/YAML config) starts with `# SPDX-License-Identifier: GPL-3.0-only`. Markdown, JSON, `.gitignore` and `LICENSE` carry none. |

---

## 4. Architecture

### 4.1 System view

```
┌──────────────────────────── Sony Bravia 4K ────────────────────────────┐
│            HDMI (video/audio)            HDMI-CEC (remote keys)        │
└───────────────▲──────────────────────────────────┬─────────────────────┘
                │                                  │
┌───────────────┴──────── Raspberry Pi 4B · Fedora (KIWI image) ─────────┴┐
│  systemd: egsob.service (user egsob, DRM master on the console)         │
│  ┌──────────────────────────── egsob (Rust) ─────────────────────────┐  │
│  │ egsob-app  ── Slint UI (KMS/DRM) ── libmpv render (OpenGL ES)     │  │
│  │     │                                                             │  │
│  │ egsob-core (services, navigation state, event bus)                │  │
│  │  ├─ egsob-input     CEC (/dev/cec0) · evdev keyboard/mouse        │  │
│  │  ├─ egsob-player    libmpv wrapper, tracks, subtitles, OSD state  │  │
│  │  ├─ egsob-addons    manifests, package mgr, Rhai, repo client     │  │
│  │  ├─ egsob-resolver  yt-dlp mgmt, HLS/DASH, DRM detection          │  │
│  │  ├─ egsob-catalog   TMDB, Stremio bridge, search                  │  │
│  │  ├─ egsob-torrent   librqbit, RAM cache, HTTP stream to mpv       │  │
│  │  ├─ egsob-subtitles OpenSubtitles REST                            │  │
│  │  ├─ egsob-epg       guide data import/storage                     │  │
│  │  ├─ egsob-data      rusqlite, migrations, encrypted secrets       │  │
│  │  └─ egsob-api       axum: local API + phone web remote (PIN)      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│  /var/lib/egsob: egsob.db · secret.key (0600) · addons/ · yt-dlp/       │
└─────────────────────────────────────────────────────────────────────────┘
        ▲ dnf upgrade (COPR)        ▲ add-on index (GitHub EGSetOpBox-addons)
```

Process model: **single binary** (D-42); the crates above are libraries linked into `egsob-app`.

### 4.2 Repository layout (main repo `EGSetOpBox`)

```
EGSetOpBox/
├── EGSetOpBox-Chat-Master.md
├── EGSetOpBox-Code-Master.md
├── EGSetOpBox-Issue-Master.md
├── README.md  LICENSE  CLAUDE.md  .claude/settings.json
├── Cargo.toml  Cargo.lock     # workspace
├── rust-toolchain.toml  rustfmt.toml  clippy.toml
├── .copr/Makefile             # COPR make_srpm
├── scripts/                   # check-limits.sh and other gate scripts
├── crates/
│   ├── egsob-app/  egsob-core/  egsob-input/  egsob-player/
│   ├── egsob-addons/  egsob-resolver/  egsob-catalog/  egsob-torrent/
│   ├── egsob-subtitles/  egsob-epg/  egsob-data/  egsob-api/
├── ui/                        # .slint files, translations (gettext .po)
├── web-remote/                # static phone remote page served by egsob-api
├── packaging/rpm/egsetopbox.spec
├── packaging/systemd/egsob.service
├── os/kiwi/                   # KIWI description (Pi aarch64 + x86_64 VM profile)
├── vm/                        # KVM x86_64 + QEMU aarch64 scripts
├── .github/workflows/
└── docs/spikes/               # spike findings
```

Add-on repository `EGSetOpBox-addons`: `index.json` + one folder per add-on.

### 4.3 Add-on package (draft spec, finalized in M4)

```toml
# manifest.toml
[addon]
id = "channel.euronews.en"      # reverse-dns-like, unique
name = "Euronews (EN)"
version = "1.0.0"               # semver
api = 1                         # add-on API version
description = "Euronews live in English"
icon = "assets/icon.png"
languages = ["en"]

[[capability]]
kind = "channel"                # channel | catalog | stream | subtitles | stremio
type = "youtube"                # youtube | hls | dash | direct
youtube_channel_id = "UC..."    # stable identity, resolved at play time
number = 101                    # default channel number
group = "News"

[script]                        # optional — only when logic is needed
entry = "main.rhai"
net_allow = ["example-broadcaster.tld"]   # network allowlist for the script
```

- Stremio bridge: `kind = "stremio"`, `transport_url = "https://…/manifest.json"`; the core speaks the Stremio protocol (`/{resource}/{type}/{id}.json`).
- Stream results are one of: `url` (HTTP/HLS/DASH), `yt:<id>`, `magnet:`/infohash (→ torrent engine).
- Rhai host API (finalized in M4): HTTP GET with allowlist, JSON, regex, logging, return `StreamRef`.
- Package integrity: `index.json` lists `id`, `version`, `url`, `sha256`; the box verifies the hash before install.

### 4.4 Data (SQLite, sketch)

`settings`, `secrets` (encrypted values), `addons`, `channels` (number, group, favourite), `groups`, `epg_programmes`, `watch_progress`, `history`, `remote_tokens` (phone pairing), `schema_migrations`.

### 4.5 Playback paths

- **YouTube live/VOD:** add-on → `yt:<id>` / channel identity → resolver (yt-dlp) → mpv.
- **Broadcaster HLS/DASH:** add-on (optional Rhai) → current URL → DRM check → mpv.
- **Torrent:** stream add-on → magnet/infohash → librqbit (RAM cache) → local HTTP stream → mpv.
- **Subtitles:** OpenSubtitles (IMDb/TMDB ID or file hash) → `.srt` → mpv `sub-add`.

---

## 5. Toolchain and environments

| Purpose | Tool |
|---|---|
| Language | Rust, edition 2024, toolchain = Fedora 44's rustc (D-44) |
| UI | Slint (GPLv3), LinuxKMS backend, FemtoVG renderer (D-43) |
| Player | libmpv (Fedora/RPM Fusion) |
| HTTP | axum, reqwest |
| DB | rusqlite (+ migrations) |
| Scripting | Rhai |
| Torrent | librqbit |
| YouTube | yt-dlp (self-managed copy) |
| CEC | Linux CEC API (`/dev/cec0`), `cec-ctl` from v4l-utils for diagnostics |
| OS image | KIWI NG (Fedora descriptions as reference); Pi boot needs the first partition FAT, bootable |
| Packaging | RPM spec, COPR |
| CI | GitHub Actions (arm64 runners) |
| VMs | x86_64 KVM VM (fast UI/logic smoke tests); aarch64 QEMU TCG VM (image/RPM validation, slow); CEC simulated with the kernel `vivid` driver |
| Real hardware | Pi 4B on the Bravia (video decode, CEC, performance) |

---

## 6. Constraints and known risks

- Fedora's Pi video acceleration is limited; HEVC hardware decode depends on the upstream Pi HEVC driver. Plan for 1080p H.264.
- KMS/DRM without a compositor: the UI and mpv must share one GL context (libmpv render API inside Slint) — validated in spike M0.
- yt-dlp breaks when YouTube changes; mitigated by self-update (D-19).
- microSD write endurance: no torrent disk cache; consider volatile journald later if needed.
- OpenSubtitles free quota is limited per day.
- Legal: the torrent engine and Stremio bridge are content-agnostic; the box ships no infringing sources.
- 4K30 UI output (D-68) puts more load on the Pi 4 GPU through FemtoVG; the Slint spike measures it.

---

## 7. Open decisions (resolve with the engineer — do not assume)

| # | Question | Resolve in |
|---|---|---|
| O-01 | ~~Exact Fedora release number for "N-1".~~ **Resolved → D-03 (Fedora 44).** | — |
| O-02 | ~~Process model.~~ **Resolved → D-42 (single binary).** | — |
| O-03 | ~~Slint renderer on KMS/DRM.~~ **Resolved → D-43 (FemtoVG).** | — |
| O-04 | mpv hwdec policy on Fedora 44/Pi. Spike must check: whether Fedora's kernel exposes the Pi H.264 (`v4l2m2m-copy`) and HEVC (`drm-copy`) decoders; that `hwdec=auto` is **not** used (its whitelist skips both and falls back to software silently); whether yt-dlp should prefer H.264 ≤1080p, since YouTube usually serves VP9/AV1, which the Pi 4 can't decode in hardware. | M0 spike `Spike — hardware video decode reality check on Fedora/Pi` |
| O-05 | ~~Rust edition and MSRV.~~ **Resolved → D-44 (edition 2024, Fedora 44 rustc).** | — |
| O-06 | ~~Device access.~~ **Resolved → D-45 (libseat + logind).** | — |
| O-07 | ~~Rhai host API and limits.~~ **Resolved → D-46 (Minimal + HTML).** | — |
| O-08 | ~~EPG sources.~~ **Resolved → D-47 (own CI guide + add-on override).** | — |
| O-09 | ~~Add-on signing.~~ **Resolved → D-48 (sha256 only).** | — |
| O-10 | ~~yt-dlp updates.~~ **Resolved → D-49 (stable binary, verified swap, boot + daily).** | — |
| O-11 | ~~Auvio live DRM.~~ **Resolved → D-50 (M0 spike decides; login → `api = 2` cookies).** | — |
| O-12 | ~~VM smoke test definition.~~ **Resolved → D-51 (scripted + checklist, run by the engineer).** | — |
| O-13 | ~~Exact rustc version in Fedora 44.~~ **Resolved → 1.99.1** (Fedora 44 updates, 2026-10-19, from the Fedora package pages). Later drift is caught by the M0-08 CI check (D-77). | — |
| O-14 | ~~Tool availability.~~ **Resolved:** Fedora 44 ships `tokei` 15.0.0 (JSON output built in; Slint is in tokei's language list, and M0-06's AC verifies the Fedora build counts `.slint`) and `ShellCheck` 0.11.0; `lizard` is not packaged (→ pip, D-78). | — |

---

## 8. Milestones, epics, features and item titles

Item titles follow the Issue Master title format. Bodies are drafted just in time (Issue Master §1). Titles are a starting backlog and can be split or merged when drafted.

### M0 — Foundations & spikes

Prerequisite (not an issue): the engineer creates the empty repo; settings per D-52. Exit criteria: D-71. No due date.

Items are listed **in implementation order** (phases A → E). `Deps` names the items that must be merged first (for spikes: findings merged). Epic in brackets.

**Phase A — Repo & gate**

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-01 | `Repo — add master files, README, GPL-3.0 licence and Claude Code config` (one-off cap waiver, Issue Master §5.3) | E0.1 | repo created |
| M0-30 | `Docs — record wave A planning decisions` | E0.1 | 01 |
| M0-02 | `Workspace — scaffold Cargo workspace with all 12 egsob-* crates` (one-off cap waiver; fills README Build section) | E0.1 | 30 |
| M0-03 | `Workspace — pin rust-toolchain.toml to the Fedora 44 rustc` | E0.1 | 02 |
| M0-04 | `Workspace — add rustfmt and clippy configuration` | E0.1 | 02 |
| M0-05 | `Gate — clippy.toml and workspace lints for cognitive complexity ≤15` | E0.2 | 04 |
| M0-06 | `Gate — code limits script (300 code lines, CCN ≤15, no inline tests)` | E0.2 | 02 |
| M0-07 | `CI — fmt, clippy and test workflow on arm64 runner` | E0.2 | 03, 04 |
| M0-08 | `CI — check rust-toolchain.toml matches the Fedora 44 rustc` | E0.2 | 07 |
| M0-09 | `CI — run code limits script in the PR workflow` | E0.2 | 06, 08 |
| M0-10 | `CI — shellcheck on all shell scripts` | E0.2 | 09 |

**Phase B — Spikes** (D-70: code PR closed unmerged; findings PR merges `docs/spikes/` + Chat Master)

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-11 | `Spike — Slint on KMS/DRM with libmpv render in one GL context as egsob via logind` | E0.6 | 02 |
| M0-12 | `Spike — hardware video decode reality check on Fedora/Pi` (resolves O-04) | E0.6 | 01 |
| M0-13 | `Spike — kernel CEC key events from the Bravia remote` | E0.6 | 01 |
| M0-14 | `Spike — RTBF Auvio live streams check (DRM, login, stream format)` (settles D-50) | E0.6 | 01 |

**Phase C — Image base & VM** (before the app, so runtime issues can be smoke-tested)

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-15 | `KIWI — Fedora aarch64 description with Pi firmware and FAT boot partition` | E0.4 | 01 |
| M0-16 | `KIWI — x86_64 profile for the smoke-test VM` | E0.4 | 15 |
| M0-17 | `VM — x86_64 KVM VM script for smoke tests` | E0.5 | 16 |
| M0-18 | `VM — vivid CEC emulation setup` | E0.5 | 17 |
| M0-19 | `VM — smoke test script (start egsob, send CEC keys, check journal, screenshot)` | E0.5 | 18 |

**Phase D — App & packaging**

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-20 | `App — placeholder Slint screen with name and version on KMS` | E0.1 | 11, 19 |
| M0-21 | `Packaging — systemd unit egsob.service` | E0.3 | 11 |
| M0-22 | `Packaging — udev rule for /dev/cec0` | E0.3 | 13 |
| M0-23 | `Packaging — RPM spec for egsetopbox` (binary, unit, udev rule, sysusers.d) | E0.3 | 20, 21, 22 |
| M0-24 | `CI — build test RPM in Fedora container` | E0.2 | 07, 23 |
| M0-25 | `COPR — project setup and build-from-git configuration` | E0.3 | 23 |

**Phase E — Pi image & release**

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-26 | `KIWI — enable RPM Fusion free and COPR repos` | E0.4 | 15, 25 |
| M0-27 | `KIWI — create egsob user, autostart service, network (Ethernet + Wi-Fi)` | E0.4 | 26 |
| M0-28 | `CI — build KIWI image on tag and attach to GitHub Release` | E0.2 | 27 |
| M0-29 | `VM — aarch64 QEMU script booting the KIWI image` | E0.5 | 27 |

Release step (engineer, not an issue): tag `v0.1.0` → COPR build + release image → flash the Pi → verify the D-71 exit criteria.

### M1 — Player core
- **E1.1 Player**
  - `Player — libmpv wrapper crate egsob-player`
  - `Player — play URL from command line on the TV`
  - `Player — expose time, duration, pause and track state`
- **E1.2 Player UI**
  - `PlayerView — fullscreen video surface in Slint`
  - `PlayerView — OSD with play/pause, seek bar and title`
  - `PlayerView — rewind/fast-forward and ±10 s seek`
- **E1.3 Keyboard**
  - `Input — keyboard events mapped to navigation actions`

### M2 — Input
- **E2.1 CEC**
  - `Input — open /dev/cec0 and claim playback device address`
  - `Input — map CEC user-control codes to actions`
  - `Input — handle TV standby and active source`
- **E2.2 Mouse & unified actions**
  - `Input — mouse pointer and click support in Slint`
  - `Input — unified action bus (Up/Down/Left/Right/OK/Back/Play/Pause/Ch±/digits)`
- **E2.3 Focus navigation**
  - `UI — focus model for 10-foot navigation`

### M3 — Data & settings
- **E3.1 Database**
  - `Data — rusqlite connection and migration runner`
  - `Data — initial schema (settings, addons, channels, groups)`
- **E3.2 Secrets**
  - `Data — key file creation and AEAD secret store`
  - `Data — secrets API for API keys and tokens`
- **E3.3 Settings UI**
  - `SettingsView — settings screen with categories`
  - `SettingsView — API key entry (TMDB, OpenSubtitles)`
  - `Logging — tracing to journald with level from settings`

### M4 — Add-on system
- **E4.1 Manifest & packages**
  - `Addons — manifest.toml schema and validation`
  - `Addons — install, remove, enable and disable packages`
- **E4.2 Rhai runtime**
  - `Addons — Rhai engine with host API and network allowlist`
  - `Addons — script execution limits and error reporting`
- **E4.3 Repository**
  - `Addons — EGSetOpBox-addons repo with index.json`
  - `Addons — fetch index, verify sha256, update installed add-ons`
- **E4.4 Add-on UI**
  - `AddonsView — browse, install and remove add-ons`

### M5 — Live TV
- **E5.1 Resolvers**
  - `Resolver — managed yt-dlp copy with scheduled self-update`
  - `Resolver — YouTube channel identity to live stream`
  - `Resolver — HLS/DASH passthrough with DRM detection`
- **E5.2 Channel add-ons**
  - `Addon — Euronews channel`
  - `Addon — Jovem Pan News channel`
  - `Addon — Revista Oeste channel`
  - `Addon — RTBF channel (per spike O-11)`
- **E5.3 Channel list & zapping**
  - `LiveTV — channel list with numbers and groups`
  - `LiveTV — CH+/CH− and digit zapping`
  - `LiveTV — favourites`
- **E5.4 EPG**
  - `AddonsRepo — EPG grabber workflow publishing guide.xml`
  - `EPG — guide data import and storage`
  - `LiveTV — guide grid view (now/next)`

### M6 — VOD catalog
- **E6.1 Metadata**
  - `Catalog — TMDB client (movies, series, seasons, episodes)`
  - `Catalog — image cache for posters and backdrops`
- **E6.2 Browse & search**
  - `HomeView — hybrid home: left menu and poster rows`
  - `DetailView — title details, seasons and episodes`
  - `SearchView — search bar with on-screen keyboard`
- **E6.3 Stremio bridge**
  - `Catalog — Stremio protocol client (catalog/meta/stream/subtitles)`
  - `Addons — stremio bridge capability`
- **E6.4 Library**
  - `Library — watch progress and continue watching`

### M7 — Torrent streaming
- `Torrent — librqbit session with bounded RAM cache`
- `Torrent — sequential piece priority for playback`
- `Torrent — local HTTP stream endpoint for mpv`
- `PlayerView — buffering and peer status overlay`

### M8 — Subtitles
- `Subtitles — OpenSubtitles REST client with quota handling`
- `Subtitles — automatic selection pt-BR > en > fr > nl`
- `PlayerView — subtitle and audio track picker`

### M9 — Phone remote & polish
- `API — axum server with PIN pairing and token auth`
- `WebRemote — phone remote page (d-pad, playback, search text)`
- `i18n — gettext translations EN, PT-BR, FR, NL`
- `Boot — boot straight to the UI with splash`
- `Polish — performance pass on the Pi at 1080p`

---

## 9. PM chat system prompt (for planning sessions)

```
You are the planning partner for EGSetOpBox, a Rust + Slint + libmpv TV box on a
Raspberry Pi 4B running a KIWI-built Fedora image. Load EGSetOpBox-Chat-Master.md
(decisions, architecture, backlog) as binding context. When drafting a GitHub issue,
load EGSetOpBox-Issue-Master.md first and follow it exactly. Never assume: if a
decision is missing or two sources conflict, ask the engineer with selectable
options plus a free-text answer, then record the decision in the Chat Master
(§3, §7 and the change log). Never add AI attribution anywhere. Create issues on
GitHub only from Claude Code on the dev host (D-74); the issues must be correct
when the session ends.
```

---

## 10. References used in the design

- Fedora Raspberry Pi 4 support: https://fedoraproject.org/wiki/Changes/RaspberryPi4
- Fedora KIWI descriptions: https://forge.fedoraproject.org/releng/kiwi-descriptions
- KIWI Pi boot partition bug: https://bugzilla.redhat.com/show_bug.cgi?id=2328768
- Pi HEVC decoder driver (upstream patches): https://patchew.org/linux/20260304-media-rpi-hevc-dec-v6-0-93868ae6dff8@raspberrypi.com
- Linux HDMI CEC docs: https://docs.kernel.org/6.14/admin-guide/media/cec.html
- Stremio add-on protocol: https://github.com/Stremio/stremio-addon-sdk
- Kodi addon.xml: https://kodi.wiki/view/Addon.xml
- OpenSubtitles API: https://opensubtitles.tawk.help/article/about-the-api
- Slint licence: https://unpkg.com/slint-ui@1.17.1/LICENSE.md

---

## 11. Change log

- **v1 (initial):** File created from the design session: decisions D-01…D-41, architecture, add-on draft spec, milestones M0–M9 with epics and item titles, open decisions O-01…O-12.
- **v2 (2026-11-18):** Resolved O-01 (D-03 → Fedora 44), O-02 (D-42 single binary), O-03 (D-43 FemtoVG), O-05 (D-44 edition 2024 + Fedora 44 rustc). O-04 stays open for the M0 decode spike, now with what the spike must check. §4.1 and §5 updated to match.
- **v3 (2026-11-18):** Resolved O-06 (D-45 libseat + logind), O-07 (D-46 Rhai Minimal + HTML), O-08 (D-47 EPG from own CI grabber + add-on override), O-09 (D-48 sha256 only), O-10 (D-49 yt-dlp stable binary with verified swap, at boot + daily).
- **v4 (2026-11-18):** Resolved O-11 (D-50 Auvio settled by M0 spike; login-only sources → Rhai `api = 2` with cookies) and O-12 (D-51 scripted VM smoke test + per-issue checklist, run by the engineer). All open decisions O-01…O-12 resolved except O-04 (decode policy, M0 spike). Backlog: added VM smoke test script item; Auvio spike retitled.
- **v5 (2026-11-18):** D-34 gate now includes the code limits check. M0 backlog: added three gate-tooling items (clippy cognitive threshold, code limits script, CI step).
- **v6 (2026-11-18):** M0 planning session. Added D-52…D-74 (planning sessions write to GitHub only from Claude Code on the dev host, Claude Code config, repo, epics, agent, scaffold, toolchain, binary, lints, limits tooling incl. `.slint`, CI runner, COPR, versioning, service user/restart, KIWI builds and contents, audio, display, VMs, spikes, M0 exit, README). Added O-13, O-14 (facts to verify at drafting). §4.2 layout extended. §6 adds 4K30 GPU risk. §8 M0 rewritten as an ordered list M0-01…M0-29 with dependencies; new items: toolchain pin, toolchain CI check, shellcheck, KIWI x86_64 profile, udev rule, placeholder app; the logind check folds into the Slint spike; VM phase moved before the app. Code Master updated in step: `.slint` limit, shellcheck gate, unwrap/unsafe rules, spike two-PR flow, Claude Code config.
- **v7 (2026-11-18):** Wave A planning. Added D-75…D-87 (Cargo.lock, scaffold details, exact toolchain pin with failing CI check, lizard via pip replaces rust-code-analysis-cli, Actions by major tag + cache, drafting waves, issue #1 exception, dev host upgrade to Fedora 44, pre-VM runtime checks, wave A sequencing, MSRV in the scaffold, CI triggers, SPDX on TOML/YAML). D-59 points to lizard. O-13 and O-14 resolved. §8: new M0-30 docs item before M0-02; M0-06 retitled; M0-09 and M0-10 chained after M0-08 because they edit the same workflow file.
