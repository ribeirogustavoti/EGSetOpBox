# EGSetOpBox

A personal TV set-top box: a Rust application with a 10-foot interface (Slint + libmpv) on a Raspberry Pi 4B, running a custom Fedora image built with KIWI NG and connected to a Sony Bravia 4K TV.

It plays live channels delivered as add-ons, browses movie and series catalogs, streams torrents, fetches subtitles from OpenSubtitles, and is controlled by the TV remote (HDMI-CEC), keyboard, mouse and a phone web remote.

## Status

Milestone M0 (Foundations & spikes) is complete: release `v0.1.0` boots on the Pi and shows a placeholder screen on the Bravia. Next: M1 (Player core).

## Project documents

- [`EGSetOpBox-Chat-Master.md`](EGSetOpBox-Chat-Master.md) — decisions, architecture and backlog.
- [`EGSetOpBox-Issue-Master.md`](EGSetOpBox-Issue-Master.md) — GitHub issue format.
- [`EGSetOpBox-Code-Master.md`](EGSetOpBox-Code-Master.md) — implementation rules and quality gate.

## Build

In fedora-devel, the x86_64 Fedora 44 dev box (Chat Master D-129):

```sh
sudo dnf install rustup gcc clang pkgconf-pkg-config \
    libdrm-devel mesa-libgbm-devel mesa-libEGL-devel \
    libinput-devel libseat-devel libxkbcommon-devel systemd-devel \
    fontconfig-devel freetype-devel
rustup-init -y
cargo build --workspace
cargo test --workspace
cargo run -p egsob-app    # prints "egsob 0.1.0 (<git hash>, <build time> UTC)"
```

## Images and releases

Images are built on the laptop (the image host, with kiwi-ng and libvirt; Chat Master D-129, D-130), from copies of the repository's `os/` and `vm/` directories kept side by side.

1. Release: tag `main` as `vX.Y.Z` and push the tag. `.github/workflows/release.yml` builds the aarch64 `egsob` binary and uploads the artifact `egsob-aarch64`.
2. Pi image: `os/build-image.sh Pi` downloads the newest successful `egsob-aarch64` artifact with `gh` and builds the image into `~/.cache/egsob/kiwi/pi/`.
3. VM image: in fedora-devel, `cargo build --release -p egsob-app`; then on the laptop, `os/build-image.sh VM` copies that binary over SSH and builds the image into `~/.cache/egsob/kiwi/vm/`.

## Flashing the Pi and first boot

1. Check which device is the microSD card with `lsblk` (here `/dev/mmcblk0`). Everything on it is overwritten.
2. Write the image; only `dd` runs as root:

   ```sh
   xzcat ~/.cache/egsob/kiwi/pi/EGSetOpBox.aarch64-<version>-0.raw.xz | sudo dd of=/dev/mmcblk0 bs=4M conv=fsync status=progress
   ```

3. Mount the card's first partition (FAT, `/dev/mmcblk0p1`) and create `egsob-wifi.txt` in its root with two lines, `SSID=<name>` and `PSK=<passphrase>`. At boot the box imports it into NetworkManager and deletes it (Chat Master D-106). Unmount the card.
4. Boot the Pi on the Bravia (HDMI0) with a USB keyboard. Text initial-setup creates the user `admin` (Chat Master D-104); afterwards the placeholder screen appears.
5. Log in with `ssh admin@egsob` (keys only; use the Pi's IP if the name does not resolve).

## VMs and smoke test

- [`docs/vm-libvirt.md`](docs/vm-libvirt.md) — the x86_64 image as the libvirt VM `egsob` in virt-manager.
- [`docs/vm-libvirt-aarch64.md`](docs/vm-libvirt-aarch64.md) — the Pi image in the emulated aarch64 VM `egsob-pi`.
- [`vm/smoke.sh`](vm/smoke.sh) — the smoke test against the VM `egsob`, run on the laptop.

## Legal

The torrent engine and the Stremio bridge are content-agnostic. This project ships no content sources; what is played is the user's responsibility. DRM-protected streams are not supported, and DRM is never circumvented.

## Licence

GPL-3.0-only — see [`LICENSE`](LICENSE). A personal, private-use project; it is not distributed as a product.
