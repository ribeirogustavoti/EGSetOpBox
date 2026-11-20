# Pi setup for the M0 spikes

Manual preparation of the Raspberry Pi 4B for the spike runs (Chat Master D-89, amended by D-111). The Pi runs the **EGSetOpBox KIWI image** (D-105) on a 32 GB microSD card, on **Wi-Fi only**. **SELinux stays enforcing.** Steps marked *(M0-11)* or *(M0-13)* are only needed for that spike.

## 1. Starting point

The Pi already has:

1. The KIWI `Pi` image written to the microSD card, with `egsob-wifi.txt` on the FAT boot partition (D-106).
2. The first boot done on the Bravia (HDMI0) with a USB keyboard. Text initial-setup created user `admin` (D-104).
3. SSH access from the dev host as `admin@egsob` (key preset in the image; use the Pi's IP if the name does not resolve).
4. The system updated with `sudo dnf -y upgrade --refresh` and rebooted.

From here on, work over SSH; the keyboard can stay on the Pi for console checks.

## 2. Check SELinux

```sh
getenforce
```

It must print `Enforcing`. Do not switch to permissive. After each spike run, collect any denials and hand them in with the spike's logs:

```sh
sudo ausearch -m avc -ts boot 2>/dev/null || sudo journalctl -b -k --grep 'avc:'
```

A denial is a spike finding, not something to fix by hand.

## 3. Enable RPM Fusion free and full ffmpeg (D-05)

```sh
sudo dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf -y install --allowerasing ffmpeg
```

`--allowerasing` replaces `ffmpeg-free` libraries if any are installed. Record any other conflict `dnf` reports as a finding.

## 4. Packages for the spikes

```sh
sudo dnf -y install mpv mpv-libs v4l-utils curl jq socat \
    mesa-dri-drivers mesa-libEGL mesa-libgbm libinput libseat libxkbcommon fontconfig
```

`ffprobe` (used by M0-12) comes with `ffmpeg` from section 3.

## 5. Service user `egsob` (M0-11, M0-13)

```sh
sudo useradd --system --create-home --home-dir /var/lib/egsob egsob
```

No extra groups: M0-11 must reach the display through logind (D-45), and M0-13 reaches `/dev/cec0` through the temporary rule below.

## 6. Temporary CEC access rule (M0-13)

```sh
echo 'SUBSYSTEM=="cec", KERNEL=="cec0", OWNER="egsob", MODE="0600"' |
    sudo tee /etc/udev/rules.d/99-egsob-cec-spike.rules
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=cec
ls -l /dev/cec0
```

`ls -l` must show owner `egsob`. If `/dev/cec0` does not exist, record that as a spike finding.

## 7. Spike service on tty1 (M0-11)

Create the sample directory, owned by `egsob`:

```sh
sudo install -d -o egsob -g egsob /var/lib/egsob/spike
```

Create `/etc/systemd/system/egsob-spike.service`:

```ini
[Unit]
Description=EGSetOpBox spike on tty1 (Slint + libmpv)
After=systemd-user-sessions.service
Conflicts=getty@tty1.service

[Service]
User=egsob
PAMName=login
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal
UtmpIdentifier=tty1
UtmpMode=user
ExecStart=/usr/local/bin/egsob-spike-slint-mpv /var/lib/egsob/spike/sample-h264-1080p.mov
```

Do **not** enable it at boot. Run it only during the spike:

```sh
sudo systemctl daemon-reload
sudo systemctl start egsob-spike.service
journalctl -u egsob-spike -f
loginctl list-sessions
```

`loginctl` must list an active session for `egsob` on `tty1`. A `Could not activate session: Permission denied` error in the journal is a finding (D-45).

## 8. Getting spike binaries onto the Pi (D-91)

1. Open the spike PR's workflow run on GitHub in the dev host's browser and download the artifact. It is uploaded unzipped, so the download is the binary itself.
2. Copy it to the Pi:

   ```sh
   scp <binary> admin@egsob:/tmp/
   ssh admin@egsob 'sudo install -m 0755 /tmp/<binary> /usr/local/bin/ && sudo restorecon -v /usr/local/bin/<binary>'
   ```

Shell spikes are copied the same way, without the download step: `scp spikes/<name>/run.sh admin@egsob:~/`.

## 9. After all four spikes

Nothing is cleaned up by hand. Once the last findings PR is merged, the microSD card is **re-flashed** with a freshly built KIWI image (D-105, D-111), `egsob-wifi.txt` is copied onto its FAT boot partition again, and first boot runs initial-setup again.
