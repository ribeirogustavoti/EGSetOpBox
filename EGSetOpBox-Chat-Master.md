
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
| D-05 | Codecs | **RPM Fusion free** enabled in both images (full ffmpeg/libavcodec for mpv), installed by `config.sh` (D-141). |
| D-06 | Updates | No field deployment. The box is updated by **re-flashing the KIWI image** (D-113). |
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
| D-20 | DRM | Widevine/other DRM is **not supported and never circumvented**. The resolver detects DRM in HLS/DASH manifests and the UI shows "DRM-protected – not playable". RTBF Auvio: D-50. |
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
| D-33 | Git workflow | **Branch + PR per issue**: branch `issue-<n>-<slug>`, PR body `Closes #<n>`, merged to `main` with a **merge commit** (D-103). |
| D-34 | PR gate | `cargo fmt --check`, `cargo clippy -D warnings`, `cargo test --workspace`, **code limits check** (≤300 code lines per `.rs`/`.js`/`.slint` file, cyclomatic and cognitive complexity ≤15, tests in separate files — rules in `EGSetOpBox-Code-Master.md`, CODE LIMITS), **shellcheck** (D-60), **VM smoke test** (D-51). |
| D-35 | Dev host | Development happens in **fedora-devel**, an x86_64 Fedora 44 VM on the laptop; images and VMs live on the laptop (D-129). |
| D-36 | Builds | **GitHub Actions arm64 runners** for CI: the PR gate and the aarch64 release binary (D-131). Images are built on the laptop (D-130). No RPM and no COPR (D-113). |
| D-37 | Logging | **tracing → journald** (`journalctl -u egsob`), log level in settings. |
| D-38 | Crate prefix | **`egsob-*`**. |
| D-39 | Master files | Three files at the **repo root**: `EGSetOpBox-Chat-Master.md`, `EGSetOpBox-Code-Master.md`, `EGSetOpBox-Issue-Master.md`. |
| D-40 | Subtitles | OpenSubtitles **REST API** (`api.opensubtitles.com`), API key + optional account as secrets; respect daily download quota. |
| D-41 | Milestones | M0–M9 as listed in §8 (approved). |
| D-42 | Process model | **Single binary** `egsob`: UI, libmpv, add-ons, resolver, torrent and axum API in one process. (UI and video must share one process anyway: separate processes contending for DRM caused frame drops on Pi 4 in other projects.) |
| D-43 | Slint renderer | **FemtoVG** (OpenGL ES 2.0) on the **LinuxKMS** backend; libmpv renders through the libmpv OpenGL render API into the same GL context. |
| D-44 | Rust toolchain | **Edition 2024**. MSRV = the **rustc version shipped in Fedora 44** repos (the CI release build uses it, D-115); pinned in `rust-toolchain.toml` and checked in CI. |
| D-45 | Device access | **libseat via systemd-logind**: `egsob.service` runs as user `egsob` with a logind session on tty1 (`PAMName`/`TTYPath`, D-123), no root. Slint built with libseat + libinput. `/dev/cec0` reached through a udev rule (D-124). A logind failure (known Fedora kiosk pitfall: "Could not activate session: Permission denied") is fixed when it shows (D-119). |
| D-46 | Rhai host API (api = 1) | **Minimal + HTML**: `http_get`/`http_post` with headers, JSON, regex, HTML parsing with CSS selectors, logging, return `StreamRef`. No cookies (possible later as `api = 2`). Always-on limits: max operations, call depth, expression depth, string/array/map sizes, per-call wall-clock timeout, `eval` and `import` disabled, per-add-on network allowlist (`net_allow`). |
| D-47 | EPG sources | **Both**: a GitHub Action in `EGSetOpBox-addons` runs the iptv-org/epg grabber for the installed channels and publishes `guide.xml` (default); a channel add-on may override it with its own XMLTV URL + channel id. The core only downloads and parses XMLTV (no grabber on the box). Channels without data show name only. |
| D-48 | Add-on integrity | **sha256 only** (in `index.json`, fetched over HTTPS from GitHub). No signatures. |
| D-49 | yt-dlp | Official **`yt-dlp_linux_aarch64`** standalone binary, **stable** channel, in `/var/lib/egsob/yt-dlp/`. Update = **verified swap**: download → check against SHA2-256SUMS → self-test (`--version` + resolve one known YouTube live) → atomic swap, previous version kept for automatic rollback. Runs **at boot and daily** (systemd timer). |
| D-50 | RTBF Auvio | The M0 spike that was to settle it was not run (D-119). When the RTBF add-on is planned, it checks La Une, Tipik and La Trois live from the Brussels connection: (a) DRM present? (b) login required? (c) plain HLS/DASH? If DRM → RTBF add-on uses RTBF's YouTube channels. If no DRM but login required → extend the Rhai host API with a per-add-on cookie jar as **`api = 2`**, Auvio credentials stored as encrypted secrets (D-22). |
| D-51 | VM smoke test | **Scripted + checklist.** `vm/smoke.sh` runs on the laptop against the libvirt domain `egsob` (D-134); its checks are in D-108. Each issue's AC adds a short manual checklist of what must be seen, looked at in virt-manager's graphical console (D-139). **Run by the engineer** during PR review (not by the AI agent). Video quality is judged only on the Pi. |
| D-52 | Repository | `ribeirogustavoti/EGSetOpBox`, public. Engineer creates it empty; settings: default branch `main`; merge method per D-103 (merge commits); branches are not deleted on merge. **No branch protection** on `main`. |
| D-53 | Epics | Tracked **only in §8**. GitHub issues carry the milestone only (no epic issues, no Project board). |
| D-54 | M0 agent | **Claude Code** implements every M0 issue. |
| D-55 | Workspace scaffold | **All 12 `egsob-*` crates** are scaffolded in one issue (one-off cap waiver, Issue Master §5.3). |
| D-56 | Toolchain use | **rustup everywhere** (dev host and CI), driven by `rust-toolchain.toml` pinned to the Fedora 44 rustc version (D-44). |
| D-57 | Binary | Crate `egsob-app` builds the binary via `[[bin]] name = "egsob"`. |
| D-58 | Lints and format | Workspace lints: `clippy::cognitive_complexity` (threshold 15), **`clippy::pedantic` warn**, **`clippy::unwrap_used` and `clippy::expect_used` deny** outside tests, **`unsafe_code` deny** (FFI crates opt in at crate level). Only the Slint-generated `mod ui` may carry `#[allow(clippy::unwrap_used)]` (D-128). `rustfmt.toml` holds `edition = "2024"` only. |
| D-59 | Code limits tooling | Bash script **`scripts/check-limits.sh`**. `tokei` and `lizard` (D-78) come from **Fedora RPMs where packaged**, otherwise a pinned upstream install (`cargo install --locked`, or `pip` for lizard, D-78). The 300-code-line limit also covers **`.slint`** files. |
| D-60 | CI runner | GitHub-hosted **`ubuntu-24.04-arm`** running a **`fedora:44` container**; **arm64 only**. **shellcheck** runs on every `.sh` file in the PR gate. |
| D-61 | COPR | Superseded by D-113. |
| D-62 | Versioning | **SemVer 0.x**, one version for workspace and image; tags `vX.Y.Z`. |
| D-63 | Service user | Superseded by D-122. |
| D-64 | Service restart | `egsob.service`: `Restart=always`, `RestartSec=2`. |
| D-65 | KIWI builds | Both images are built **on the laptop** by `os/build-image.sh VM` or `Pi` (D-130) from the description in `os/kiwi/` (D-105): `Pi` (aarch64 raw disk) embeds the aarch64 binary from `release.yml` (D-131); `VM` (x86_64 qcow2) is the smoke-test VM image. Images are not published to GitHub (D-143). |
| D-66 | Image contents | Boot chain = **Fedora default** (Pi firmware → U-Boot → UEFI → GRUB). Root FS **btrfs**, kept at the image size (D-135). `en_US.UTF-8`, `Europe/Brussels`, hostname `egsob` (restored after initial-setup, D-140). **sshd on, key-only**; accounts per D-104, keys per D-135. **Wi-Fi from a boot-partition file** (D-106). Credentials are never in the image. |
| D-67 | Audio | **ALSA direct** (mpv `ao=alsa`) to HDMI; no sound server. |
| D-68 | Display | Bravia on **HDMI0** (`/dev/cec0` expected). KMS output **3840×2160@30**; video stays 1080p (D-02) and is scaled. The Pi kernel command line is `console=tty1 quiet`, so the console and initial-setup appear on the Bravia (M0-34, #45). |
| D-69 | VMs | x86_64: the libvirt domain `egsob` (D-133). aarch64: the emulated libvirt domain `egsob-pi` (D-142), for image userspace checks, not Pi firmware boot (pass rule D-117). Scripts are **Bash + shellcheck**. |
| D-70 | Spikes | Superseded by D-148. |
| D-71 | M0 exit | All M0 items closed and the **M0 exit run** on tag `v0.1.0` passes (D-146). **No due date.** |
| D-72 | README | Summary + GPL-3.0-only + private-use note; pointers to the three masters; legal note (content-agnostic torrent/Stremio, no DRM circumvention); a **Build** section (workspace scaffold); status, image build, flashing and first boot, and VM pointers (D-150). |
| D-73 | Claude Code config | Repo root `CLAUDE.md` points the agent to the three masters and restates the no-attribution rule; `.claude/settings.json` sets `"attribution": {"commit": "", "pr": ""}` so Claude Code adds no trailer or PR footer. |
| D-74 | Planning sessions | Planning chats draft the milestone and its issues **and create them on GitHub**, and the issues must be correct when the session ends; the engineer does no clean-up. Any session that writes to GitHub runs in **Claude Code in fedora-devel** (D-129) with the engineer's own `gh` login and attribution off (`~/.claude/settings.json` and D-73). Cloud sessions that add attribution to GitHub writes never write to GitHub. Drafts are delivered as **body-only files**; title, milestone and assignee are given separately. No automated attribution check. |
| D-75 | Cargo.lock | Committed. Issues list it in Where as `(NEW — generated by cargo)` or `(MODIFY — generated by cargo)`; it needs no Source Code Sample. |
| D-76 | Scaffold details | Workspace version **0.1.0**. `egsob` prints `egsob <version> (<hash>, <build time> UTC)` (D-118) unless `EGSOB_UI=1` is set (D-121). Dependencies follow §4.1: `egsob-app` → `egsob-core` → the 10 service crates, declared as path entries in `[workspace.dependencies]`. Every crate has `[lints] workspace = true` (the root carries `[workspace.lints]`), an SPDX line plus a `//!` doc line, and the same text as its Cargo `description`; `publish = false`. `.gitignore` (`/target`) comes with the scaffold. |
| D-77 | Toolchain pin | `rust-toolchain.toml` holds the **exact** version of Fedora 44's `rust` package (updates repo). The CI check (M0-08) **fails** when they differ; the engineer bumps the pin through a small issue. Refines D-44 and D-56. |
| D-78 | Cyclomatic tool | **lizard** measures per-function cyclomatic complexity for `.rs` and `.js` (replaces `rust-code-analysis-cli`, which is not packaged in Fedora and has had no release for about 3 years). Not packaged in Fedora 44: installed with **`pip install --user lizard==1.23.0`** on the dev host and in CI. `lizard forgives` suppression comments are forbidden; the limits script fails on them. |
| D-79 | GitHub Actions | Actions referenced by **major tag** (`actions/checkout@v6`, `actions/cache@v6`); cargo registry and `target/` cached. |
| D-80 | Drafting waves | M0 bodies are drafted per wave; a wave starts once the items it depends on are merged. Each wave starts with a `Docs — record <wave> planning decisions` issue. Issues are created on GitHub by a Claude Code prompt run in fedora-devel (D-74). |
| D-81 | Issue #1 | Pushed directly to `main` without a PR, because the repo had no `main` branch yet. One-off exception to D-33. |
| D-82 | Dev host release | The dev host was upgraded from Fedora 37 to **Fedora 44** (confirmed 2026-11-18); D-35 means Fedora 44. |
| D-83 | Pre-VM runtime checks | Superseded by D-108. |
| D-84 | Wave A sequencing | The dev host is upgraded to Fedora 44 **before M0-06** is dispatched; M0-30 and M0-02…M0-05 run on the current host with rustup. |
| D-85 | MSRV | The workspace sets `rust-version` to the same value as `rust-toolchain.toml` (D-77) and every crate inherits it; set in the scaffold (M0-02). **1.100.0** since M0-46 (was 1.99.1). |
| D-86 | CI runs | The CI workflow runs on **pull requests to `main`** and **pushes to `main`**. A CI issue is accepted when its own PR run is green. |
| D-87 | SPDX on config | Every TOML and YAML file (Cargo manifests, toolchain/rustfmt/clippy config, GitHub workflows, KIWI/YAML config) starts with `# SPDX-License-Identifier: GPL-3.0-only`. Markdown, JSON, `.gitignore` and `LICENSE` carry none. |
| D-88 | M0 reopened | The GitHub milestone `M0 — Foundations & spikes` was closed with only Phase A done (#1–#11) and **reopened**; phases B–G are finished **in M0**. M1 issues are dispatched only after the M0 exit run (D-146). M1 is planned in a separate session after the exit. |
| D-89 | Spike Pi | Superseded by D-148. |
| D-90 | Spike code | Superseded by D-148. |
| D-91 | Spike builds | Superseded by D-148. |
| D-92 | Spike languages | Superseded by D-148. |
| D-93 | Spike findings | Superseded by D-148. |
| D-94 | Wave B | Superseded by D-119. |
| D-95 | Decode spike (M0-12) | Superseded by D-148. |
| D-96 | Slint spike (M0-11) | Superseded by D-148. |
| D-97 | CEC spike (M0-13) | Superseded by D-148. |
| D-98 | Auvio spike (M0-14) | Superseded by D-148. |
| D-99 | Wave B docs issue | Superseded by D-148. |
| D-100 | Wi-Fi in the KIWI image | Superseded by D-106. |
| D-101 | Spike findings deferred | Superseded by D-119. |
| D-102 | CEC spike code on `main` | Superseded by D-148. |
| D-103 | Merge method | PRs are merged with **merge commits**. Direct pushes to `main` stay exceptions (D-81). |
| D-104 | Image accounts | The image creates **no login user**. On first boot, Fedora's **text initial-setup** (USB keyboard + TV on the Pi; serial console in `egsob`; graphical console in `egsob-pi`) creates user **`admin`** with a password, marked administrator (`wheel`, sudo with password). The SSH keys are preset in `/etc/ssh/authorized_keys.d/admin` (D-135); sshd allows **keys only**, no root login. **Root stays locked.** Applies to the Pi and both VMs. |
| D-105 | KIWI description | Own description in `os/kiwi/` (`egsob.kiwi`, `config.sh`, `editbootinstall_rpi.sh`, `root/` overlay), modelled on Fedora's KIWI descriptions (`BootDiskCore` aarch64 disk type: MBR, FAT ESP set to type 0x06, U-Boot copied to `rpi-u-boot.bin`, `bcm283x-firmware`, btrfs root). Profiles **`Pi`** (aarch64 raw disk) and **`VM`** (x86_64 qcow2, UEFI only with `eficsm="false"`, D-135). Built on the laptop by `os/build-image.sh` (D-130); the `Pi` profile with **`system boxbuild`** (`--box universal --aarch64 --machine virt --cpu cortex-a72 --box-smp-cpus 4 --box-memory 8G --no-accel`); outputs in **`~/.cache/egsob/kiwi/`**, never committed. Keyboard layout `us`. |
| D-106 | Wi-Fi file | file **`egsob-wifi.txt`** in the root of the FAT ESP (`/boot/efi` on the box) with lines `SSID=<name>` and `PSK=<passphrase>`. `egsob-wifi-import.service` runs at every boot when the file exists, creates the NetworkManager connection `egsob-wifi` with `nmcli`, and deletes the file. The passphrase is never logged. |
| D-107 | Smoke-test VM | The VM itself is D-133. In the VM image only, `vivid` loads at boot and `/dev/cec*` belongs to group `wheel` with mode 0660 (`60-egsob-vm-cec.rules`), plus the sudoers file of D-138. |
| D-108 | Smoke test scope | `vm/smoke.sh` checks boot/SSH, that `egsob`'s output starts with `egsob <version> ` (D-118), that `egsob.service` is active, and the vivid CEC key round-trip (D-138); it saves the journals. No screenshot (D-139). Checks grow with later issues (D-51). |
| D-109 | Wave C | Wave C = **M0-32 → M0-15 → M0-33 → M0-16 → M0-17 → M0-18 → M0-19**, one by one, each after the previous one merges. M0-15 is accepted on a successful build on the dev host; the first Pi boot is M0-33. |
| D-110 | Phase D blocked items | Superseded by D-119. |
| D-111 | Spikes on the KIWI image | Superseded by D-119. |
| D-112 | Wave D | Superseded by D-119. |
| D-113 | Software delivery | **No RPM and no COPR, permanently.** The `egsob` binary (`/usr/bin/egsob`, D-130), `egsob.service`, the `/dev/cec0` udev rule and the `egsob` user are **embedded in the KIWI images**. The box is updated by **re-flashing** the image. |
| D-114 | Image file locations | `egsob.service` and the udev rule live **directly in the KIWI overlay** (`os/kiwi/root/…`; paths in D-123 and D-124). |
| D-115 | Binary into the image | The `Pi` image takes the newest successful `release.yml` artifact `egsob-aarch64` (D-131); the `VM` image takes fedora-devel's `target/release/egsob` (D-130). Its path in both images is **`/usr/bin/egsob`**. |
| D-116 | Image CI fallback | Superseded by D-143. |
| D-117 | aarch64 VM pass rule | The aarch64 check passes when the Pi image boots in `egsob-pi` (D-142), initial-setup completes on its graphical console, and **key-only SSH as `admin`** works. |
| D-118 | Placeholder build info | The placeholder screen (M0-20) shows **name, version, git short hash and build time (UTC)**. `egsob-app`'s `build.rs` (M0-36) sets them; `egsob` prints `egsob <version> (<hash>, <YYYY-MM-DD HH:MM> UTC)`. Hash = first 7 hex digits of `HEAD` from `git`, with `-dirty` when tracked files have changes. Build time = `SOURCE_DATE_EPOCH` if set, otherwise the clock. Either part falls back to `unknown`. `build.rs` re-runs only when the git `HEAD`, the current branch ref or `packed-refs` change. Build info is a separate item, **M0-36**, so M0-20 needs no cap waiver. |
| D-119 | Spikes closed | The engineer chose to build on without spike results; problems are fixed when they show. Spike issues **#23–#26 are closed as not planned**; spike branches are kept, and the spike rules and `spikes/cec/run.sh` are removed (D-148). O-04, O-15 and O-16 are closed without findings. Fact on record: the M0-11 spike workflow built **Slint 1.18** (`backend-linuxkms`, `renderer-femtovg`) with rustc 1.99.1 on `fedora:44` aarch64 (PR #29). |
| D-120 | Wave D part 2 | Order, each after the previous one merges: **M0-38 → M0-39 → M0-40 → M0-21 → M0-22 → M0-20**. Phase E (M0-26, M0-37, M0-27, M0-28, M0-29) is drafted in a later session. |
| D-121 | UI switch | `egsob` runs the Slint UI only when **`EGSOB_UI=1`**; otherwise (unset or any other value) it prints the D-118 version line and exits, so `vm/smoke.sh` keeps working over SSH. |
| D-122 | `egsob` user | Created by **`os/kiwi/root/usr/lib/sysusers.d/egsob.conf`**: system user `egsob`, home `/var/lib/egsob`, in both images (M0-21). |
| D-123 | `egsob.service` | `os/kiwi/root/usr/lib/systemd/system/egsob.service`: user `egsob`, logind session on tty1 (`PAMName=login`, `TTYPath=/dev/tty1`, D-45), `Conflicts=getty@tty1` (D-132), `Environment=EGSOB_UI=1`, `ExecStart=/usr/bin/egsob`, `Restart=always`/`RestartSec=2` (D-64). **Enabled at boot in both images** (M0-21). |
| D-124 | CEC udev rule | `os/kiwi/root/usr/lib/udev/rules.d/50-egsob-cec.rules`: `SUBSYSTEM=="cec", KERNEL=="cec0", OWNER="egsob", MODE="0600"` (M0-22). In the VM, the later `60-egsob-vm-cec.rules` (D-107) still sets group `wheel` and mode 0660 for the smoke test. |
| D-125 | Runtime packages | Both images install `mesa-dri-drivers`, `mesa-libEGL`, `mesa-libgbm`, `libinput`, `libseat`, `libxkbcommon`, `fontconfig` and `dejavu-sans-fonts` (M0-40). The CI gate installs the matching `-devel` packages for building Slint (M0-39). |
| D-126 | Placeholder screen | `ui/placeholder.slint`, compiled by `egsob-app`'s `build.rs` with `slint-build`; Slint **1.18** with `backend-linuxkms` and `renderer-femtovg`. Near-black background; `EGSetOpBox` large and white in the centre; below it the D-118 build line smaller and grey; a live **HH:MM** clock (24-hour, local time zone from the system, D-66) in a corner, read with **`chrono`** (`Local::now`). |
| D-127 | Unverified samples | When the planning session cannot compile a Rust sample (no crate downloads), the issue's creation prompt builds the samples on the dev host (fmt, clippy, test) in a temporary worktree **before** creating the issue, and stops on failure. Refines D-74. |
| D-128 | Slint-generated code | `slint::include_modules!()` expands to code that calls `unwrap()`. It lives in its own module, `mod ui` in `crates/egsob-app/src/main.rs`, and only that module carries `#[allow(clippy::unwrap_used)]`; everything else stays under D-58. Found by the M0-20 creation check (D-127). |
| D-129 | Machines | **Dev box = `fedora-devel`**, an x86_64 Fedora 44 VM on the laptop (`grbonis@192.168.122.13`, repository at `~/Development/EGSetOpBox`): Rust, Java, Claude Code and `gh`; **no kiwi-ng**. **Image host = the laptop** (Fedora with GNOME): kiwi-ng, libvirt/virt-manager, `gh` and all VMs, including fedora-devel and `egsob`; no Rust toolchain. The laptop gets the repository files (`os/`, `vm/`, `docs/`) by **copying**, not by `git clone`. |
| D-130 | Binary in the images | Both images contain **`/usr/bin/egsob`**. **`os/build-image.sh VM\|Pi`** runs on the laptop: it stages the binary into a temporary copy of `os/kiwi` and runs KIWI (VM: `system build`; Pi: `system boxbuild`), with output in `~/.cache/egsob/kiwi/vm\|pi`. VM: it **copies** `target/release/egsob` from fedora-devel over SSH (no remote build; `EGSOB_DEV`, `EGSOB_DEV_REPO`). Pi: it downloads the newest successful `egsob-aarch64` artifact with `gh`. `config.sh` fails the build without the binary (M0-43). |
| D-131 | Release workflow | `.github/workflows/release.yml` builds the aarch64 release binary on **`v*` tags and manual dispatch** and uploads the artifact `egsob-aarch64` (M0-37). |
| D-132 | No shared folder; tty1 | The VM does not mount the repository (no virtiofs, no `/usr/bin/egsob` symlink). `egsob.service` always runs the UI on tty1 (`Conflicts=getty@tty1`, no `ConditionPathExists`). Admins use **SSH** (and the serial console in the VM); there is no login prompt on tty1. |
| D-133 | libvirt VM | The x86_64 image runs as the libvirt domain **`egsob`** on the laptop (`qemu:///system`), from `/var/lib/libvirt/images/egsob.qcow2`: UEFI, 4 vCPU, 4 GB, virtio GPU with 3D, SPICE GL, default network. It is visible in virt-manager. The steps are **documented, not scripted**, in `docs/vm-libvirt.md` (M0-44). There is no `vm/run-x86.sh`. |
| D-134 | Smoke test on libvirt | `vm/smoke.sh` runs on the laptop (user in the `libvirt` group) against the domain `egsob` (`EGSOB_VM` selects another); `vm/vivid-cec.sh` is piped over SSH. Its checks are in D-108. |
| D-135 | Image fixes | VM `<type>` has **`eficsm="false"`** (UEFI only, no GRUB `i386-pc`). `admin` accepts the **laptop key** (`…hmh8TljEQ6+ grbonis@fedora`) and the **fedora-devel key** (`…LweXorRNNz1F`). **`systemd-repart` is masked** in both images and there is no `/etc/repart.d/50-root.conf`, so the **Pi root stays at the image size** (about 4 GB). |
| D-136 | Wave E | Order, each after the previous one merges: **M0-41 → M0-42 → M0-37 → M0-43 → M0-44 → M0-45**. The creation prompt reads fedora-devel's `~/.ssh/id_ed25519.pub` to fill the key in M0-42. |
| D-137 | Wave F | Phase E order, each after the previous one merges: **M0-47 → M0-48 → M0-49 → M0-27 → M0-26 → M0-29**; M0-28 is removed (D-143). Planned after the wave E verification on the laptop (2026-11-23): the VM shows the placeholder with the right hash; boot, version and service checks pass; CEC, screenshot and hostname failed (D-138…D-140); `os/build-image.sh` failed its cleanup (M0-48). |
| D-138 | vivid CEC in the VM | The vivid CEC round-trip needs (1) vivid's capture control **`hdmi_000_0_is_connected_to=2`** ("Output HDMI 000-0"), so the box adapter gets a physical address; (2) keys sent to the logical address the box adapter **actually** claims (it got 8, not 4); (3) root for `v4l2-ctl` and `cec-ctl --monitor`. The VM image (only) has `/etc/sudoers.d/egsob-vm-cec`: `admin` may run `/usr/bin/cec-ctl` and `/usr/bin/v4l2-ctl` as root without a password (M0-49). |
| D-139 | No screenshot | QEMU cannot screenshot the virtio-GPU 3D (OpenGL) display (`screendump: no surface`). `vm/smoke.sh` has no screenshot check; the engineer looks at virt-manager's graphical console. |
| D-140 | Hostname | O-17 cause: initial-setup **empties `/etc/hostname`** on the first boot (the image writes `egsob`; the next boot reports "No hostname configured"). `egsob-hostname.service` (overlay, both images) runs after `initial-setup.service` when `/etc/hostname` is missing or empty and runs `hostnamectl set-hostname egsob` (M0-27). |
| D-141 | RPM Fusion and ffmpeg | Both images: `config.sh` installs `rpmfusion-free-release` from mirrors.rpmfusion.org (repositories and signing keys), then `ffmpeg` and `ffmpeg-libs` with `--allowerasing`; signature checking stays on (M0-26). Implements D-05. |
| D-142 | aarch64 VM | The Pi image is checked in an emulated aarch64 libvirt VM `egsob-pi` on the laptop (TCG, UEFI, `virt`, Cortex-A72, `qemu-system-aarch64-core` + `edk2-aarch64`), documented in `docs/vm-libvirt-aarch64.md` (M0-29); initial-setup runs on its graphical console. |
| D-143 | No release image upload | Images built on the laptop are not uploaded to GitHub Releases; M0-28 is removed. |
| D-144 | Wave G | Order, each after the previous one merges: **M0-50 → M0-51 → M0-52 → M0-53 → M0-54**. Documentation only. All five issues are created at once by one creation prompt in fedora-devel (D-74), milestone M0, assignee `ribeirogustavoti`. |
| D-145 | Pre-tag check | 2026-11-24: the Pi image built by `os/build-image.sh Pi` with build `1509d11` (`main` after PR #90) shows the placeholder (name, version, build line, clock) on the Bravia; on the Pi, the Wi-Fi file import, hostname `egsob` and key-only SSH as `admin` work; `vm/smoke.sh` is fully green; `docs/vm-libvirt-aarch64.md` was followed end to end (PR #90 test plan). The local `v0.1.0` tag made for this run is deleted and not pushed. |
| D-146 | M0 exit run | After M0-54 merges: (1) tag `main` as **`v0.1.0`** and push; `release.yml` builds `egsob-aarch64`, and that run must be the newest successful one. (2) On the laptop, `os/build-image.sh Pi`, flash (README, D-150), `egsob-wifi.txt` on the FAT partition, first boot. On the Pi: the placeholder shows the tag's hash; Wi-Fi imported, hostname `egsob`, key-only SSH as `admin`; Ethernet gets a DHCP address (`nmcli device status`); `rpm -q ffmpeg ffmpeg-libs` lists both; `/dev/cec0` is owned by `egsob` with mode 0600; `journalctl -b -k --grep avc:` finds no denial. (3) In fedora-devel, `git checkout v0.1.0` and `cargo build --release -p egsob-app`; on the laptop, `os/build-image.sh VM`, the domain `egsob` replaced per `docs/vm-libvirt.md`, `vm/smoke.sh` green, and the placeholder hash equals the tag's. The result is recorded in the first M1 docs issue; the engineer closes the M0 milestone by hand. |
| D-147 | Masters cleanup | Every §3 row is rewritten to its **current final text**; a fully superseded row becomes a one-line pointer (`Superseded by D-x.`); the history lives only in the §11 change log (M0-51). |
| D-148 | Spike rules removed | The Code Master spike paragraph and Issue Master §5.4 are removed (M0-52); D-70 and D-89…D-98 become pointers (M0-51); `spikes/cec/run.sh` is deleted (M0-54). §8 Phase B stays as a closed record. Spike branches on GitHub are left as they are. |
| D-149 | Issue exemplars | Issue Master §7 names two merged issues as the canonical exemplars: **#58** (code: Rust, `.slint`, `build.rs`, `Cargo.lock`) and **#82** (OS image: KIWI overlay and `config.sh`). #58's screendump and `vm/run-x86.sh` AC lines are historical (D-133, D-139) and are not copied. Issue Master §5 subsections are put in order (M0-52). |
| D-150 | README | `README.md` gains: status (M0 complete, `v0.1.0`); building images on the laptop (tag → `release.yml` → `os/build-image.sh VM` or `Pi`, output in `~/.cache/egsob/kiwi/`); flashing and first boot (`xzcat` of `~/.cache/egsob/kiwi/pi/EGSetOpBox.aarch64-<version>-0.raw.xz` piped to `sudo dd of=/dev/mmcblk0 bs=4M conv=fsync status=progress`, so only `dd` runs as root; `egsob-wifi.txt`; text initial-setup creates `admin`; SSH); pointers to `docs/vm-libvirt.md`, `docs/vm-libvirt-aarch64.md` and `vm/smoke.sh` (M0-53). |
| D-151 | pi-setup removed | `docs/pi-setup.md` (the spike preparation guide) is deleted, with every reference to it (M0-54). |
| D-152 | Project copies | After wave G merges, the claude.ai project copies of the three masters are replaced with the files on `main`. |
 
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
        ▲ re-flash image (built on the laptop, D-130)   ▲ add-on index (GitHub EGSetOpBox-addons)
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
├── os/build-image.sh          # image build on the laptop (D-130)
├── vm/                        # smoke test against the libvirt VM (D-134)
├── .github/workflows/
└── docs/                      # spike findings, pi-setup.md, vm-libvirt.md (D-133)
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
| Delivery | KIWI image with the embedded `egsob` binary, built on the laptop; updates by re-flashing (D-113, D-130, D-143) |
| CI | GitHub Actions (arm64 runners) |
| VMs | libvirt domain `egsob` on the laptop (x86_64, D-133; smoke tests with `vm/smoke.sh`); aarch64 QEMU TCG VM (image validation, slow); CEC simulated with the kernel `vivid` driver |
| Real hardware | Pi 4B on the Bravia (video decode, CEC, performance) |
 
---
 
## 6. Constraints and known risks
 
- Fedora's Pi video acceleration is limited; HEVC hardware decode depends on the upstream Pi HEVC driver. Plan for 1080p H.264.
- KMS/DRM without a compositor: the UI and mpv must share one GL context (libmpv render API inside Slint) — not validated yet (the M0 spike was not run, D-119).
- yt-dlp breaks when YouTube changes; mitigated by self-update (D-19).
- Re-flashing for every update (D-113) wipes `/var/lib/egsob` (database, secret key, add-ons) unless it is backed up first.
- The Pi root partition is not grown to the card size (D-135); space is limited to the image's root size.
- microSD write endurance: no torrent disk cache; consider volatile journald later if needed.
- OpenSubtitles free quota is limited per day.
- Legal: the torrent engine and Stremio bridge are content-agnostic; the box ships no infringing sources.
- 4K30 UI output (D-68) puts more load on the Pi 4 GPU through FemtoVG; not measured yet (D-119).
---
 
## 7. Open decisions (resolve with the engineer — do not assume)
 
| # | Question | Resolve in |
|---|---|---|
| O-01 | ~~Exact Fedora release number for "N-1".~~ **Resolved → D-03 (Fedora 44).** | — |
| O-02 | ~~Process model.~~ **Resolved → D-42 (single binary).** | — |
| O-03 | ~~Slint renderer on KMS/DRM.~~ **Resolved → D-43 (FemtoVG).** | — |
| O-04 | mpv hwdec policy on Fedora 44/Pi. Spike must check: whether Fedora's kernel exposes the Pi H.264 (`v4l2m2m-copy`) and HEVC (`drm-copy`) decoders; that `hwdec=auto` is **not** used (its whitelist skips both and falls back to software silently); whether yt-dlp should prefer H.264 ≤1080p, since YouTube usually serves VP9/AV1, which the Pi 4 can't decode in hardware. | ~~M0 spike~~ Closed without findings (D-119) |
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
| O-15 | Slint and `libmpv2` crate versions for M0-11 (latest stable Slint last seen: 1.18.1, 2026-09-21) and their MSRV against 1.99.1. Verify at M0-11 drafting. | Closed without findings (D-119) |
| O-16 | Public sample URLs for M0-12 (D-95) and the YouTube channel identities of Euronews, Jovem Pan News, DW News and Revista Oeste. The planning chat researches them; the engineer approves before the issue is created. | Closed without findings (D-119) |
| O-17 | ~~VM hostname changes from `egsob` to `fedora`.~~ **Resolved → D-140** (initial-setup empties `/etc/hostname`). | — |
 
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
 
**Phase B — Spikes** (D-70: code PR closed unmerged; findings PR merges `docs/spikes/` + Chat Master). Order and rules: D-89…D-99. **Closed as not planned (D-119).**
 
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
 
**Phase D — App & image files.** Order and rules: D-113…D-127 (part 2 order: D-120).

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-35 | `Docs — record wave D planning decisions` (#47) | E0.1 | 34 |
| M0-35a | `Docs — retarget pi-setup for KIWI image spike runs` (#48; split from M0-35 for the cap) | E0.1 | 35 |
| M0-36 | `App — build info (git short hash, build date) via build.rs` (#50; D-118) | E0.1 | 19 |
| M0-38 | `Docs — record wave D part 2 decisions` | E0.1 | 35a, 36 |
| M0-39 | `CI — install Slint build dependencies in the gate job` (D-125) | E0.2 | 38 |
| M0-40 | `KIWI — runtime libraries and fonts for egsob` (D-125) | E0.4 | 39 |
| M0-21 | `KIWI — egsob user, egsob.service unit, enabled at boot` (D-121…D-123) | E0.3 | 40 |
| M0-22 | `KIWI — udev rule for /dev/cec0 in the image overlay` (D-124) | E0.3 | 21 |
| M0-20 | `App — placeholder Slint screen with name, version, build info and clock on KMS` (D-121, D-126) | E0.1 | 22, 36 |
| M0-41 | `Docs — record wave E planning decisions` | E0.1 | 20 |
| M0-42 | `KIWI — UEFI-only VM disk, admin SSH keys and masked systemd-repart` (D-135) | E0.4 | 41 |
| M0-37 | `CI — build the aarch64 release binary on tag` (D-131; moved from Phase E) | E0.2 | 42 |
| M0-43 | `Image — egsob inside both images, built on the laptop by os/build-image.sh` (D-130, D-132) | E0.4 | 37 |
| M0-44 | `Docs — run the EGSetOpBox VM in virt-manager` (D-133) | E0.5 | 43 |
| M0-45 | `VM — smoke test against the libvirt VM` (D-134) | E0.5 | 44 |

**Phase E — Pi image & release.** Order and rules: D-137…D-143.

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-46 | `Workspace — bump the Rust toolchain pin to Fedora 44's 1.100.0` (D-77, D-85) | E0.1 | 45 |
| M0-47 | `Docs — record wave F planning decisions` | E0.1 | 46 |
| M0-48 | `Image — fix the cleanup in os/build-image.sh` | E0.4 | 47 |
| M0-49 | `VM — working vivid CEC round-trip in the smoke test` (D-138, D-139) | E0.5 | 48 |
| M0-27 | `KIWI — keep the egsob hostname after initial-setup` (D-140; plus a network check on the Pi) | E0.4 | 49 |
| M0-26 | `KIWI — enable RPM Fusion free with ffmpeg and ffmpeg-libs` (D-141) | E0.4 | 27 |
| M0-29 | `Docs — run the Pi image in an aarch64 libvirt VM` (D-142) | E0.5 | 26 |

M0-28 is removed (D-143).

**Phase G — M0 close-out.** Order and rules: D-144…D-152. Documentation only.

| ID | Title | Epic | Deps |
|---|---|---|---|
| M0-50 | `Docs — record wave G planning decisions` | E0.1 | 29 |
| M0-51 | `Docs — rewrite Chat Master decision rows to their final text` (D-147) | E0.1 | 50 |
| M0-52 | `Docs — Code and Issue Master cleanup (spike rules, §5 order, exemplars)` (D-148, D-149) | E0.1 | 51 |
| M0-53 | `Docs — README status, image build, flashing and VM pointers` (D-150) | E0.1 | 52 |
| M0-54 | `Docs — remove pi-setup.md and the CEC spike script` (D-148, D-151) | E0.1 | 53 |

Release step (engineer, not an issue): the M0 exit run on tag `v0.1.0` (D-146), after M0-54 merges.

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
- **v12 (2026-11-21):** Wave D part 2 planning. Added D-119…D-127 (spikes #23–#26 closed without runs, wave D part 2 order, `EGSOB_UI=1` switch, `egsob` user via sysusers.d, `egsob.service` enabled at boot with the VM symlink, CEC udev rule, runtime and CI packages, placeholder screen with a `chrono` clock, creation prompts compile unverified samples, `unwrap_used` allowed only on the Slint-generated module). D-101, D-110, D-111 and D-112 superseded; D-45, D-58, D-63, D-70, D-71, D-76 and D-115 amended; D-111 now points to M0-35a (#48). §7 O-04/O-15/O-16 closed. §8: Phase B closed; Phase D adds M0-35a, M0-38…M0-40 and reorders M0-21 → M0-22 → M0-20; M0-27 retitled.
- **v13 (2026-11-22):** Wave E planning. Added D-129…D-136 (fedora-devel as dev box, laptop as image host; `egsob` inside both images through `os/build-image.sh`; release workflow on tag and manual dispatch; no shared folder, UI owns tty1; libvirt VM documented in `docs/vm-libvirt.md`; smoke test on libvirt; VM UEFI-only, laptop and fedora-devel SSH keys, repart masked; wave E order) and O-17 (hostname). D-107 superseded; D-35, D-51, D-65, D-69, D-74, D-105, D-108, D-113, D-115 and D-123 amended. §4.1, §4.2, §5 and §6 updated. §8: Phase D adds M0-41…M0-45 and takes M0-37 from Phase E; M0-27 retitled to network only.
- **v14 (2026-11-23):** Toolchain pin and MSRV bumped from 1.99.1 to 1.100.0, Fedora 44's current `rust` (D-77, D-85; M0-46). §8 Phase E starts with M0-46.
- **v15 (2026-11-23):** Wave F (Phase E) planning after the wave E verification. Added D-137…D-143 (wave F order; vivid CEC link, real logical address and VM-only sudo; no screenshot in the smoke test; hostname restored after initial-setup; RPM Fusion and ffmpeg via `config.sh`; aarch64 libvirt VM doc; no GitHub Release image). D-116 superseded; D-05, D-65, D-71, D-108, D-117, D-134 and D-135 amended; O-17 resolved. §5 Delivery row. §8 Phase E rewritten: M0-47…M0-49 added, M0-27 retitled, M0-28 removed.
- **v16 (2026-11-24):** Wave G (M0 close-out) planning after the pre-tag check on the Pi and the laptop. Added D-144…D-152 (wave G order; pre-tag check with build `1509d11`; M0 exit run on tag `v0.1.0` with its Pi and VM checks; masters cleanup rule; spike rules and `spikes/cec/run.sh` removed; exemplars #58 and #82; README contents and flash command; `docs/pi-setup.md` removed; project copies synced after wave G). D-102 superseded; D-71 amended. §8 adds Phase G (M0-50…M0-54); the release step points to D-146.
- **v17 (2026-11-24):** Masters cleanup (D-147, M0-51): §3 rows rewritten to their current final text, with amendment notes folded in; D-61, D-63, D-70, D-83, D-89…D-102, D-110…D-112 and D-116 are now one-line pointers; D-20 and D-50 no longer rely on the M0 spikes. §6: the two risks that pointed to the M0 spikes now say they are not validated yet.
