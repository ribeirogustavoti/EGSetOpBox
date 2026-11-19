
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
| D-06 | Updates | No field deployment. The box is updated by **re-flashing the KIWI image** (replaced by D-113; no RPM, no COPR). |
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
| D-33 | Git workflow | **Branch + PR per issue**: branch `issue-<n>-<slug>`, PR body `Closes #<n>`, merged to `main` with a **merge commit** (amended by D-103). |
| D-34 | PR gate | `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test --workspace`, **code limits check** (≤300 code lines per `.rs`/`.js` file, cyclomatic and cognitive complexity ≤15, tests in separate files — rules in `EGSetOpBox-Code-Master.md`, CODE LIMITS), **VM smoke test** (D-51). |
| D-35 | Dev host | **x86_64 Fedora** workstation with KVM/QEMU. |
| D-36 | Builds | **GitHub Actions arm64 runners** for CI builds (gate, aarch64 release binary, KIWI image). No RPM and no COPR (amended by D-113). |
| D-37 | Logging | **tracing → journald** (`journalctl -u egsob`), log level in settings. |
| D-38 | Crate prefix | **`egsob-*`**. |
| D-39 | Master files | Three files at the **repo root**: `EGSetOpBox-Chat-Master.md`, `EGSetOpBox-Code-Master.md`, `EGSetOpBox-Issue-Master.md`. |
| D-40 | Subtitles | OpenSubtitles **REST API** (`api.opensubtitles.com`), API key + optional account as secrets; respect daily download quota. |
| D-41 | Milestones | M0–M9 as listed in §8 (approved). |
| D-42 | Process model | **Single binary** `egsob`: UI, libmpv, add-ons, resolver, torrent and axum API in one process. (UI and video must share one process anyway: separate processes contending for DRM caused frame drops on Pi 4 in other projects.) |
| D-43 | Slint renderer | **FemtoVG** (OpenGL ES 2.0) on the **LinuxKMS** backend; libmpv renders through the libmpv OpenGL render API into the same GL context. |
| D-44 | Rust toolchain | **Edition 2024**. MSRV = the **rustc version shipped in Fedora 44** repos (the CI release build uses it, D-115); pinned in `rust-toolchain.toml` and checked in CI. |
| D-45 | Device access | **libseat via systemd-logind**: `egsob.service` runs as user `egsob` with a logind session on tty1 (`PAMName`/`TTYPath`), no root. Slint built with libseat + libinput. `/dev/cec0` reached through a udev rule. M0 spike must confirm logind activates the session (known Fedora kiosk pitfall: "Could not activate session: Permission denied"). |
| D-46 | Rhai host API (api = 1) | **Minimal + HTML**: `http_get`/`http_post` with headers, JSON, regex, HTML parsing with CSS selectors, logging, return `StreamRef`. No cookies (possible later as `api = 2`). Always-on limits: max operations, call depth, expression depth, string/array/map sizes, per-call wall-clock timeout, `eval` and `import` disabled, per-add-on network allowlist (`net_allow`). |
| D-47 | EPG sources | **Both**: a GitHub Action in `EGSetOpBox-addons` runs the iptv-org/epg grabber for the installed channels and publishes `guide.xml` (default); a channel add-on may override it with its own XMLTV URL + channel id. The core only downloads and parses XMLTV (no grabber on the box). Channels without data show name only. |
| D-48 | Add-on integrity | **sha256 only** (in `index.json`, fetched over HTTPS from GitHub). No signatures. |
| D-49 | yt-dlp | Official **`yt-dlp_linux_aarch64`** standalone binary, **stable** channel, in `/var/lib/egsob/yt-dlp/`. Update = **verified swap**: download → check against SHA2-256SUMS → self-test (`--version` + resolve one known YouTube live) → atomic swap, previous version kept for automatic rollback. Runs **at boot and daily** (systemd timer). |
| D-50 | RTBF Auvio | Settled by the **M0 spike**, tested from the Brussels connection, for La Une, Tipik and La Trois live. It checks: (a) DRM present? (b) login required? (c) plain HLS/DASH? If DRM → RTBF add-on uses RTBF's YouTube channels. If no DRM but login required → extend the Rhai host API with a per-add-on cookie jar as **`api = 2`** (amends D-46), Auvio credentials stored as encrypted secrets (D-22). |
| D-51 | VM smoke test | **Scripted + checklist.** A `vm/` script boots the x86_64 KVM VM, starts `egsob`, sends remote keys via `cec-ctl` on the `vivid` CEC device, checks `journalctl -u egsob` for expected events and errors, and saves a QEMU `screendump` screenshot. Each issue's AC adds a short manual checklist of what must be seen. **Run by the engineer** during PR review (not by the AI agent). Video quality is judged only on the Pi. |
| D-52 | Repository | `ribeirogustavoti/EGSetOpBox`, public. Engineer creates it empty; settings: default branch `main`; merge method per D-103 (merge commits); branches are not deleted on merge. **No branch protection** on `main`. |
| D-53 | Epics | Tracked **only in §8**. GitHub issues carry the milestone only (no epic issues, no Project board). |
| D-54 | M0 agent | **Claude Code** implements every M0 issue. |
| D-55 | Workspace scaffold | **All 12 `egsob-*` crates** are scaffolded in one issue (one-off cap waiver, Issue Master §5.3). |
| D-56 | Toolchain use | **rustup everywhere** (dev host and CI), driven by `rust-toolchain.toml` pinned to the Fedora 44 rustc version (D-44). |
| D-57 | Binary | Crate `egsob-app` builds the binary via `[[bin]] name = "egsob"`. |
| D-58 | Lints and format | Workspace lints: `clippy::cognitive_complexity` (threshold 15), **`clippy::pedantic` warn**, **`clippy::unwrap_used` and `clippy::expect_used` deny** outside tests, **`unsafe_code` deny** (FFI crates opt in at crate level). `rustfmt.toml` holds `edition = "2024"` only. |
| D-59 | Code limits tooling | Bash script **`scripts/check-limits.sh`**. `tokei` and `lizard` (D-78) come from **Fedora RPMs where packaged**, otherwise a pinned upstream install (`cargo install --locked`, or `pip` for lizard, D-78). The 300-code-line limit also covers **`.slint`** files. |
| D-60 | CI runner | GitHub-hosted **`ubuntu-24.04-arm`** running a **`fedora:44` container**; **arm64 only**. **shellcheck** runs on every `.sh` file in the PR gate. |
| D-61 | COPR | **Dropped** (D-113). `Cargo.lock` stays committed (D-75). |
| D-62 | Versioning | **SemVer 0.x**, one version for workspace and image; tags `vX.Y.Z` (amended by D-113). |
| D-63 | Service user | `egsob` is created **in the KIWI image** (M0-27); no RPM (amended by D-113). |
| D-64 | Service restart | `egsob.service`: `Restart=always`, `RestartSec=2`. |
| D-65 | KIWI builds | Pi image (aarch64) built in **CI on tag** and published as a **GitHub Release asset** (`.raw.xz`); the tag workflow also builds the aarch64 `egsob` binary that the image embeds (D-115). The dev host can also build it with `kiwi-ng system boxbuild` (D-105); if CI cannot build the image, the engineer builds it on the dev host and uploads it (D-116). An **x86_64 profile** of the same description, built **on the dev host only**, is the smoke-test VM image. |
| D-66 | Image contents | Boot chain = **Fedora default** (Pi firmware → U-Boot → UEFI → GRUB). Root FS **btrfs**. `en_US.UTF-8`, `Europe/Brussels`, hostname `egsob`. **sshd on, key-only**; the engineer's public key is committed in `os/kiwi/`. Accounts per D-104. **Wi-Fi from a boot-partition file** (amended by D-100): after flashing, the engineer copies a small file with SSID and password onto the card's FAT boot partition; a first-boot service imports it into NetworkManager and deletes the file. Credentials are never in the image. |
| D-67 | Audio | **ALSA direct** (mpv `ao=alsa`) to HDMI; no sound server. |
| D-68 | Display | Bravia on **HDMI0** (`/dev/cec0` expected). KMS output **3840×2160@30**; video stays 1080p (D-02) and is scaled. The Pi kernel command line is `console=tty1 quiet`, so the console and initial-setup appear on the Bravia (M0-34, #45). |
| D-69 | VMs | x86_64 VM: KIWI x86_64 profile, **`virtio-vga-gl` + virgl**, `-display egl-headless`; `egsob` is **built on the dev host and shared** into the VM (virtiofs/9p). aarch64 VM: QEMU **`virt` + edk2 UEFI** (image userspace checks, not Pi firmware boot; pass rule D-117). Scripts are **Bash + shellcheck**. |
| D-70 | Spikes | Format per Issue Master §5.4. Agent writes the code; **engineer runs it** on the Pi, which runs the **stock Fedora 44 aarch64** image until the KIWI image exists. **Two PRs per spike:** the code PR is closed unmerged (branch kept); the findings PR merges `docs/spikes/<name>.md` and the Chat Master update. Slint spike uses the **`libmpv2` crate**; must show 1080p H.264 with **no visible stutter** (judged by eye on the Bravia, amended by D-96), UI ≥30 fps over video at 4K30 (read from an on-screen fps counter), and running as `egsob` via logind on tty1 without root (D-45). Decode spike: public sample files fetched by its script. CEC spike keys: D-pad/OK/Back, Play/Pause/Stop/FF/RW, CH+/CH−, digits. Auvio spike: run by the engineer with his own account; credentials never committed. |
| D-71 | M0 exit | All M0 items closed; the Pi boots the KIWI image and `egsob.service` shows the **placeholder screen** on the Bravia; spike findings recorded (O-04 resolved, D-50 settled, CEC and Slint findings in §3); tag `v0.1.0` builds the image (CI, or the engineer's upload per D-116) as a GitHub Release asset, the flashed Pi shows the placeholder screen, and `vm/smoke.sh` passes on the tagged build (amended by D-113). **No due date.** |
| D-72 | README | Summary + GPL-3.0-only + private-use note; pointers to the three masters; legal note (content-agnostic torrent/Stremio, no DRM circumvention); a **Build** section filled by the workspace scaffold issue. |
| D-73 | Claude Code config | Repo root `CLAUDE.md` points the agent to the three masters and restates the no-attribution rule; `.claude/settings.json` sets `"attribution": {"commit": "", "pr": ""}` so Claude Code adds no trailer or PR footer. |
| D-74 | Planning sessions | Planning chats draft the milestone and its issues **and create them on GitHub**, and the issues must be correct when the session ends; the engineer does no clean-up. Any session that writes to GitHub runs in **Claude Code on the dev host** with the engineer's own `gh` login and attribution off (`~/.claude/settings.json` and D-73). Cloud sessions that add attribution to GitHub writes never write to GitHub. Drafts are delivered as **body-only files**; title, milestone and assignee are given separately. No automated attribution check. |
| D-75 | Cargo.lock | Committed. Issues list it in Where as `(NEW — generated by cargo)` or `(MODIFY — generated by cargo)`; it needs no Source Code Sample. |
| D-76 | Scaffold details | Workspace version **0.1.0**. Until M0-20, `egsob` prints `egsob <version> (<hash>, <build time>)` (D-118). Dependencies follow §4.1: `egsob-app` → `egsob-core` → the 10 service crates, declared as path entries in `[workspace.dependencies]`. Every crate has `[lints] workspace = true` (the root carries `[workspace.lints]`), an SPDX line plus a `//!` doc line, and the same text as its Cargo `description`; `publish = false`. `.gitignore` (`/target`) comes with the scaffold. |
| D-77 | Toolchain pin | `rust-toolchain.toml` holds the **exact** version of Fedora 44's `rust` package (updates repo). The CI check (M0-08) **fails** when they differ; the engineer bumps the pin through a small issue. Refines D-44 and D-56. |
| D-78 | Cyclomatic tool | **lizard** measures per-function cyclomatic complexity for `.rs` and `.js` (replaces `rust-code-analysis-cli`, which is not packaged in Fedora and has had no release for about 3 years). Not packaged in Fedora 44: installed with **`pip install --user lizard==1.23.0`** on the dev host and in CI. `lizard forgives` suppression comments are forbidden; the limits script fails on them. |
| D-79 | GitHub Actions | Actions referenced by **major tag** (`actions/checkout@v6`, `actions/cache@v6`); cargo registry and `target/` cached. |
| D-80 | Drafting waves | M0 bodies are drafted per phase: Phase A first; a later phase starts once the items it depends on are merged (amended by D-109; pending spike findings do not block a wave). Each wave starts with a `Docs — record <wave> planning decisions` issue. Issues are created on GitHub by a Claude Code prompt run on the dev host (D-74). |
| D-81 | Issue #1 | Pushed directly to `main` without a PR, because the repo had no `main` branch yet. One-off exception to D-33. |
| D-82 | Dev host release | The dev host was upgraded from Fedora 37 to **Fedora 44** (confirmed 2026-11-18); D-35 means Fedora 44. |
| D-83 | Pre-VM runtime checks | Until M0-19 (smoke test script) is merged, issues that change runtime behaviour replace the VM smoke test AC line with a command check (e.g. `cargo run -p egsob-app` prints `egsob 0.1.0`). |
| D-84 | Wave A sequencing | The dev host is upgraded to Fedora 44 **before M0-06** is dispatched; M0-30 and M0-02…M0-05 run on the current host with rustup. |
| D-85 | MSRV | The workspace sets `rust-version = "1.99.1"` (same value as `rust-toolchain.toml`, D-77) and every crate inherits it; set in the scaffold (M0-02). |
| D-86 | CI runs | The CI workflow runs on **pull requests to `main`** and **pushes to `main`**. A CI issue is accepted when its own PR run is green. |
| D-87 | SPDX on config | Every TOML and YAML file (Cargo manifests, toolchain/rustfmt/clippy config, GitHub workflows, KIWI/YAML config) starts with `# SPDX-License-Identifier: GPL-3.0-only`. Markdown, JSON, `.gitignore` and `LICENSE` carry none. |
| D-88 | M0 reopened | The GitHub milestone `M0 — Foundations & spikes` was closed with only Phase A done (#1–#11). It is **reopened**; phases B–E are finished **in M0**. M1 issues are dispatched only after the D-71 exit. M1 planning is deferred to a later session. |
| D-89 | Spike Pi | The Pi runs the **stock Fedora 44 Minimal aarch64** image, written to the microSD with an image writer. Network: **Wi-Fi only**, joined at first boot with a **keyboard on the Pi**. **RPM Fusion free** is enabled and full ffmpeg replaces ffmpeg-free (as D-05). The `egsob` user, the tty1 logind service unit for M0-11 and a **temporary `/dev/cec0` udev rule** for M0-13 are set up **by hand** following `docs/pi-setup.md` (added by M0-31). Amended by D-111: the spikes run on the **KIWI image**. |
| D-90 | Spike code | Spike code lives in `spikes/<name>/`, **outside the Cargo workspace**, and does **not** have to pass the gate. Red **code limits** and **shellcheck** checks on spike code PRs are accepted (the PRs are never merged). |
| D-91 | Spike builds | Rust spikes are built by a **spike-only workflow file** on the spike branch (`ubuntu-24.04-arm` + `fedora:44`, Fedora's own `mpv-devel`, 0.41.0 in F44). The engineer downloads the artifact with the browser on the dev host and copies it to the Pi with `scp`. Nothing is added to `main`. |
| D-92 | Spike languages | M0-11: **Rust** (Slint + `libmpv2`). M0-12: **shell** driving the `mpv` CLI. M0-13: **shell** with `cec-ctl`. M0-14: **manual Firefox procedure + shell** manifest checker. |
| D-93 | Spike findings | The engineer supplies script logs and notes; **Claude Code writes** `docs/spikes/<name>.md` and the Chat Master update in the findings PR. |
| D-94 | Wave B | Wave B = M0-31 then the spikes **one by one in the order M0-12 → M0-11 → M0-13 → M0-14**; each spike starts after the previous spike's findings PR is merged. Wave B bodies are drafted per D-80. Spike runs and findings are **deferred** (D-101) and resume per D-111. |
| D-95 | Decode spike (M0-12) | Samples: **H.264 1080p, HEVC 1080p and 4K, VP9 1080p** (public URLs proposed by the planning chat, approved by the engineer — O-16) and **AV1 1080p, encoded on the dev host** from the H.264 sample with ffmpeg (SVT-AV1) and copied to the Pi. hwdec modes on every sample: **`no`, `v4l2m2m-copy`, `drm-copy`, `v4l2m2m`, `drm`** (never `auto`). Outputs: **`vo=gpu` with `gpu-context=drm`** and **`vo=drm`**. About 1 minute per run, unattended. YouTube: the D-49 `yt-dlp_linux_aarch64` binary lists formats (`-F`) and plays the H.264 ≤1080p format for the lives of **Euronews, Jovem Pan News, DW News and Revista Oeste** (channel identities proposed by the planning chat, approved by the engineer — O-16). Report: **script log + engineer notes** (smooth/stutter per run). |
| D-96 | Slint spike (M0-11) | Runs **after M0-12** and uses its hwdec finding. Plays a **public 1080p H.264 sample**. The Slint overlay is an **animated moving bar + on-screen fps counter**. Pass is judged **visually**: no visible stutter, and the fps counter shows ≥30 at 4K30. Amends D-70. |
| D-97 | CEC spike (M0-13) | Keys: the D-70 list only. Claims a **playback** device address, then repeats the key test as a **tuner**, and compares. Also records **TV standby, power-on, active source and input switching**. Runs as **`egsob`** with the temporary udev rule (D-89). |
| D-98 | Auvio spike (M0-14) | The engineer opens La Une, Tipik and La Trois live in **Firefox on the dev host** while logged in and copies the manifest URLs; a shell script reports DRM markers and stream format. Also tries **yt-dlp's RTBF extractor** with and without the engineer's login cookies (cookie file never committed). If DRM-free, the streams are also **played on the Pi** with mpv. |
| D-99 | Wave B docs issue | **M0-31** `Docs — record wave B planning decisions` changes `EGSetOpBox-Chat-Master.md`, `EGSetOpBox-Code-Master.md` and `docs/pi-setup.md` (NEW). Within the ≤3-file cap, so **no waiver**. AC: masters updated, `docs/pi-setup.md` present, markdown renders, gate line. |
| D-100 | Wi-Fi in the KIWI image | Amends D-66: Wi-Fi comes from a **file on the FAT boot partition**, imported and deleted at first boot. Implemented by M0-33 (D-106). |
| D-101 | Spike findings deferred | No Pi run, log, test or finding is requested from the engineer before the KIWI image exists (M0-15). Spike runs (M0-12, M0-11, M0-13, M0-14) and their findings PRs happen **after the image boots on the Pi** (M0-33); issues #23–#26 stay open until then. The spikes then run on the KIWI image instead of the stock image (D-89); `docs/pi-setup.md` is revisited at that time. O-04, O-15 and O-16 stay open until those findings merge. The wait ended on 2026-11-19 (D-111). |
| D-102 | CEC spike code on `main` | `spikes/cec/run.sh` was merged by PR #30. One-off exception to D-70/D-90: it stays on `main` as spike code (not production, no crate depends on it) and passes shellcheck. |
| D-103 | Merge method | PRs are merged with **merge commits**, as done since wave A. Amends D-33 and D-52. Direct pushes to `main` stay exceptions (D-81). |
| D-104 | Image accounts | The image creates **no login user**. On first boot, Fedora's **text initial-setup** (USB keyboard + TV on the Pi; serial console in the VM) creates user **`admin`** with a password, marked administrator (`wheel`, sudo with password). The engineer's SSH key is preset in `/etc/ssh/authorized_keys.d/admin`; sshd allows **keys only**, no root login. **Root stays locked.** Applies to the Pi and the VM. Amends D-66. |
| D-105 | KIWI description | Own description in `os/kiwi/` (`egsob.kiwi`, `config.sh`, `editbootinstall_rpi.sh`, `root/` overlay), modelled on Fedora's KIWI descriptions (`BootDiskCore` aarch64 disk type: MBR, FAT ESP set to type 0x06, U-Boot copied to `rpi-u-boot.bin`, `bcm283x-firmware`, btrfs root). Profiles **`Pi`** (aarch64 raw disk) and **`VM`** (x86_64 qcow2). Built on the dev host with `kiwi-ng`; the `Pi` profile with **`system boxbuild`** (`--box universal --aarch64 --machine virt --cpu cortex-a72 --box-smp-cpus 4 --box-memory 8G --no-accel`, as in M0-34/#45); outputs in **`~/.cache/egsob/`**, never committed. Keyboard layout `us`. |
| D-106 | Wi-Fi file | Refines D-100: file **`egsob-wifi.txt`** in the root of the FAT ESP (`/boot/efi` on the box) with lines `SSID=<name>` and `PSK=<passphrase>`. `egsob-wifi-import.service` runs at every boot when the file exists, creates the NetworkManager connection `egsob-wifi` with `nmcli`, and deletes the file. The passphrase is never logged. |
| D-107 | Smoke-test VM | **4 vCPU, 4 GB RAM**, KVM, q35, UEFI (edk2 OVMF), `virtio-vga-gl` + `egl-headless`. `vm/run-x86.sh` copies the built image once to a **persistent disk** `~/.cache/egsob/vm/x86_64.qcow2`; `firstboot` runs initial-setup on the **serial console** in the terminal; every later run uses a **throwaway overlay**. The repository is shared with **virtiofs** and mounted read-only at `/mnt/egsob` (binary: `/mnt/egsob/target/debug/egsob`). SSH via host port 2222; QMP socket for `screendump`. A rebuilt image needs `init` + `firstboot` again. In the VM only, `vivid` loads at boot and `/dev/cec*` belongs to group `wheel` (mode 0660), so the smoke test needs no sudo. |
| D-108 | Smoke test scope | `vm/smoke.sh` today checks: the VM boots, `egsob`'s output starts with `egsob <version> ` (D-118), a vivid CEC key round-trip (TV adapter → playback adapter), collects the journal and saves a PNG screendump. Checks grow with later issues (D-51). |
| D-109 | Wave C | Wave C = **M0-32 → M0-15 → M0-33 → M0-16 → M0-17 → M0-18 → M0-19**, one by one, each after the previous one merges. M0-15 is accepted on a successful build on the dev host; the first Pi boot is M0-33. |
| D-110 | Phase D blocked items | M0-20 and M0-21 wait for the M0-11 findings, and M0-22 waits for the M0-13 findings (D-101). |
| D-111 | Spikes on the KIWI image | Amends D-89 and ends the D-101 wait: the Pi booted the KIWI image on 2026-11-19. The spikes run on that image (32 GB microSD, **Wi-Fi only**, user `admin`). By hand, following `docs/pi-setup.md` (rewritten by M0-35): `dnf upgrade`, RPM Fusion free + full ffmpeg, the spike packages, user `egsob`, the temporary `/dev/cec0` udev rule and the tty1 spike unit. **SELinux stays enforcing**; any denial is a spike finding. After all four spikes, the card is **re-flashed** with a fresh image. |
| D-112 | Wave D | Wave D = **M0-35**, then the spike runs in the D-94 order (M0-12 → M0-11 → M0-13 → M0-14), each after the previous findings PR merges. Phase D bodies are drafted in the **next planning session**, once the M0-12, M0-11 and M0-13 findings have merged; M0-14 does not block that session. |
| D-113 | Software delivery | **No RPM and no COPR, permanently.** The aarch64 `egsob` binary, `egsob.service`, the `/dev/cec0` udev rule and the `egsob` user are **embedded in the KIWI image**. The box is updated by **re-flashing** the image. Replaces D-06 and D-61; amends D-36, D-44, D-62, D-63, D-65, D-69 and D-71. Items M0-23, M0-24 and M0-25 are removed from §8. |
| D-114 | Image file locations | `egsob.service` and the udev rule live **directly in the KIWI overlay** (`os/kiwi/root/…`); exact paths are set when M0-21 and M0-22 are drafted. `packaging/` and `.copr/` are removed from §4.2. |
| D-115 | Binary into the image | CI builds the **aarch64 release binary on tag** (M0-37) and the image build takes it from that artifact. On the dev host, the engineer downloads the artifact before building the image. Its path in the image is set when M0-27 is drafted. |
| D-116 | Image CI fallback | If KIWI cannot build the Pi image on the hosted arm64 runner, M0-28 becomes a release workflow that attaches an image the **engineer built on the dev host** (D-105). |
| D-117 | aarch64 VM pass rule | M0-29 passes when the image boots in the aarch64 QEMU VM, first boot completes on the serial console, and **key-only SSH as `admin`** works through a forwarded port. |
| D-118 | Placeholder build info | The placeholder screen (M0-20) shows **name, version, git short hash and build time (UTC)**. `egsob-app`'s `build.rs` (M0-36) sets them; `egsob` prints `egsob <version> (<hash>, <YYYY-MM-DD HH:MM> UTC)`. Hash = first 7 hex digits of `HEAD` from `git`, with `-dirty` when tracked files have changes. Build time = `SOURCE_DATE_EPOCH` if set, otherwise the clock. Either part falls back to `unknown`. `build.rs` re-runs only when the git `HEAD`, the current branch ref or `packed-refs` change. Build info is a separate item, **M0-36**, so M0-20 needs no cap waiver. |
 
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
        ▲ re-flash image (GitHub Release)   ▲ add-on index (GitHub EGSetOpBox-addons)
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
├── scripts/                   # check-limits.sh and other gate scripts
├── crates/
│   ├── egsob-app/  egsob-core/  egsob-input/  egsob-player/
│   ├── egsob-addons/  egsob-resolver/  egsob-catalog/  egsob-torrent/
│   ├── egsob-subtitles/  egsob-epg/  egsob-data/  egsob-api/
├── ui/                        # .slint files, translations (gettext .po)
├── web-remote/                # static phone remote page served by egsob-api
├── os/kiwi/                   # KIWI description (Pi aarch64 + x86_64 VM profile); root/ overlay holds egsob.service and the udev rule (D-114)
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
| Delivery | KIWI image with the embedded `egsob` binary; updates by re-flashing (D-113) |
| CI | GitHub Actions (arm64 runners) |
| VMs | x86_64 KVM VM (fast UI/logic smoke tests); aarch64 QEMU TCG VM (image validation, slow); CEC simulated with the kernel `vivid` driver |
| Real hardware | Pi 4B on the Bravia (video decode, CEC, performance) |
 
---
 
## 6. Constraints and known risks
 
- Fedora's Pi video acceleration is limited; HEVC hardware decode depends on the upstream Pi HEVC driver. Plan for 1080p H.264.
- KMS/DRM without a compositor: the UI and mpv must share one GL context (libmpv render API inside Slint) — validated in spike M0.
- yt-dlp breaks when YouTube changes; mitigated by self-update (D-19).
- Re-flashing for every update (D-113) wipes `/var/lib/egsob` (database, secret key, add-ons) unless it is backed up first.
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
| O-04 | mpv hwdec policy on Fedora 44/Pi. Spike must check: whether Fedora's kernel exposes the Pi H.264 (`v4l2m2m-copy`) and HEVC (`drm-copy`) decoders; that `hwdec=auto` is **not** used (its whitelist skips both and falls back to software silently); whether yt-dlp should prefer H.264 ≤1080p, since YouTube usually serves VP9/AV1, which the Pi 4 can't decode in hardware. | M0 spike `Spike — hardware video decode reality check on Fedora/Pi` (runs per D-111) |
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
| O-15 | Slint and `libmpv2` crate versions for M0-11 (latest stable Slint last seen: 1.18.1, 2026-09-21) and their MSRV against 1.99.1. Verify at M0-11 drafting. | M0-11 findings (runs per D-111) |
| O-16 | Public sample URLs for M0-12 (D-95) and the YouTube channel identities of Euronews, Jovem Pan News, DW News and Revista Oeste. The planning chat researches them; the engineer approves before the issue is created. | M0-12 run (runs per D-111) |
 
---
 
## 8. Milestones, epics, features and item titles
 
Item titles follow the Issue Master title format. Bodies are drafted just in time (Issue Master §1). Titles are a starting backlog and can be split or merged when drafted.
 
### M0 — Foundations & spikes
 
Prerequisite (not an issue): the engineer creates the empty repo; settings per D-52. Exit criteria: D-71. No due date. Milestone reopened after Phase A (D-88).
 
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
 
**Phase B — Spikes** (D-70: code PR closed unmerged; findings PR merges `docs/spikes/` + Chat Master). Order and rules: D-89…D-99; runs on the KIWI image per D-111.
 
| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-31 | `Docs — record wave B planning decisions` (D-99) | E0.1 | 10 |
| M0-12 | `Spike — hardware video decode reality check on Fedora/Pi` (resolves O-04; D-95) | E0.6 | 31 |
| M0-11 | `Spike — Slint on KMS/DRM with libmpv render in one GL context as egsob via logind` (D-96; one-off cap waiver: 5 files in Where — spike Cargo.toml, main.rs, spike-only workflow, findings doc, Chat Master) | E0.6 | 12 |
| M0-13 | `Spike — kernel CEC key events from the Bravia remote` (D-97) | E0.6 | 11 |
| M0-14 | `Spike — RTBF Auvio live streams check (DRM, login, stream format)` (settles D-50; D-98) | E0.6 | 13 |
 
**Phase C — Image base & VM** (before the app, so runtime issues can be smoke-tested). Order and rules: D-104…D-109.
 
| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-32 | `Docs — record wave C planning decisions` | E0.1 | 31 |
| M0-15 | `KIWI — Fedora aarch64 description with Pi firmware and FAT boot partition` (D-105) | E0.4 | 32 |
| M0-33 | `KIWI — import Wi-Fi credentials from a boot-partition file` (D-106; first Pi boot) | E0.4 | 15 |
| M0-16 | `KIWI — x86_64 profile for the smoke-test VM` | E0.4 | 33 |
| M0-17 | `VM — x86_64 KVM VM script for smoke tests` (D-107) | E0.5 | 16 |
| M0-18 | `VM — vivid CEC emulation setup` | E0.5 | 17 |
| M0-19 | `VM — smoke test script (start egsob, send CEC keys, check journal, screenshot)` (D-108) | E0.5 | 18 |
| M0-34 | `KIWI — use the HDMI console (tty1) on the Pi` (#45; D-68, D-105) | E0.4 | 19 |
 
**Phase D — App & image files.** Order and rules: D-110…D-118. Bodies after M0-12, M0-11 and M0-13 findings (D-112).

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-35 | `Docs — record wave D planning decisions` | E0.1 | 34 |
| M0-36 | `App — build info (git short hash, build date) via build.rs` (D-118) | E0.1 | 19 |
| M0-20 | `App — placeholder Slint screen with name, version and build info on KMS` (waits for M0-11 findings, D-110) | E0.1 | 11, 36 |
| M0-21 | `KIWI — egsob.service unit in the image overlay` (waits for M0-11 findings, D-110; D-114) | E0.3 | 11 |
| M0-22 | `KIWI — udev rule for /dev/cec0 in the image overlay` (waits for M0-13 findings, D-110; D-114) | E0.3 | 13 |

**Phase E — Pi image & release**

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-26 | `KIWI — enable RPM Fusion free (full ffmpeg)` | E0.4 | 15 |
| M0-37 | `CI — build the aarch64 release binary on tag` (D-115) | E0.2 | 07, 20 |
| M0-27 | `KIWI — egsob user, binary from the CI artifact, autostart, network (Ethernet + Wi-Fi)` (D-113, D-115) | E0.4 | 21, 22, 26, 37 |
| M0-28 | `CI — build KIWI image on tag and attach to GitHub Release` (fallback D-116) | E0.2 | 27 |
| M0-29 | `VM — aarch64 QEMU script booting the KIWI image` (D-117) | E0.5 | 27 |

Release step (engineer, not an issue): tag `v0.1.0` → CI builds the binary and the release image (or the engineer uploads it, D-116) → flash the Pi → verify the D-71 exit criteria.

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
- **v8 (2026-11-18):** Wave B planning. M0 milestone reopened (D-88). Added D-88…D-100 (spike Pi on stock F44 Minimal with Wi-Fi and RPM Fusion, spike code outside the workspace, spike-only CI build + scp, spike languages, agent-written findings, wave B order M0-31 → 12 → 11 → 13 → 14, decode/Slint/CEC/Auvio spike scopes, M0-31 files, Wi-Fi from a boot-partition file). D-66 and D-70 amended; D-82 updated (dev host on Fedora 44). Added O-15 (Slint/libmpv2 versions) and O-16 (sample URLs and YouTube channel identities). §8 Phase B reordered with new M0-31; one-off cap waiver for M0-11 recorded in §8. D-95: AV1 sample encoded on the dev host.
- **v9 (2026-11-18):** Wave C planning. Added D-101…D-110 (spike runs and findings deferred until the KIWI image boots; CEC spike code kept on `main`; merge commits; image accounts via text initial-setup with `admin` and preset SSH key; own KIWI description with `Pi`/`VM` profiles built on the dev host into `~/.cache/egsob/`; Wi-Fi file format; smoke-test VM; smoke test scope; wave C order; Phase D items waiting for findings). D-33, D-52, D-66, D-80, D-94 and D-100 amended. O-04/O-15/O-16 marked deferred. §8 Phase C adds M0-32 and M0-33; Phase D notes the blocked items.
 
- **v10 (2026-11-19):** Wave D planning. Added D-111…D-118 (spikes run on the KIWI image with SELinux enforcing and a re-flash afterwards; wave D order; no RPM and no COPR, software embedded in the image and updated by re-flashing; unit and udev rule in the KIWI overlay; aarch64 binary from CI on tag; image CI fallback; aarch64 VM pass rule; placeholder build info as M0-36). D-06 and D-61 replaced; D-36, D-44, D-62, D-63, D-65, D-69, D-71, D-89, D-94 and D-101 amended. D-68 and D-105 record #45 (`console=tty1`) and the `system boxbuild` build method. §4.1, §4.2, §5 and §6 updated for the delivery change. §8: Phase C adds M0-34 (#45); Phase D/E rewritten with M0-35…M0-37; M0-23…M0-25 removed. O-04/O-15/O-16 now run per D-111.
- **v11 (2026-11-19):** M0-36 build info: D-118 records the output format, the hash and time sources and the re-run trigger; D-76 and D-108 updated to the new `egsob` output line.
