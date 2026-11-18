# Pi setup for the M0 spikes

Manual preparation of the Raspberry Pi 4B for the wave B spikes (Chat Master D-89). The Pi runs the **stock Fedora 44 Minimal aarch64** image until the KIWI image exists. Steps marked *(M0-11)* or *(M0-13)* are only needed for that spike.

## 1. Write the image

1. On the dev host, download **Fedora Minimal 44, Raw (raw.xz), ARM aarch64** from <https://fedoraproject.org/misc/> together with its `CHECKSUM` file.
2. Verify the download with the `sha256sum -c` command shown on the download page.
3. Write the `.raw.xz` file to the microSD card with your image writer (Fedora Media Writer or `arm-image-installer`).
4. Put the card in the Pi. Connect the Pi's **HDMI0** port to the Bravia and plug a USB keyboard into the Pi.

## 2. First boot (keyboard on the Pi)

1. Power on. Complete Fedora's first-boot setup on the TV. Set the time zone to `Europe/Brussels` and create an admin user in the `wheel` group.
2. Log in on the console with that user.
3. Join the Wi-Fi network:

   ```sh
   sudo nmcli device wifi connect "<SSID>" --ask
   ```

4. Set the hostname and enable SSH:

   ```sh
   sudo hostnamectl set-hostname egsob
   sudo systemctl enable --now sshd
   ```

5. From the dev host, copy your SSH key: `ssh-copy-id <user>@egsob` (use the Pi's IP if the name does not resolve). From now on, work over SSH; the keyboard can stay on the Pi for console checks.

## 3. Update and enable RPM Fusion free (D-05)

```sh
sudo dnf -y upgrade --refresh
sudo dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf -y swap ffmpeg-free ffmpeg --allowerasing
sudo reboot
```

## 4. Packages for the spikes

```sh
sudo dnf -y install mpv mpv-libs v4l-utils curl jq socat \
    mesa-dri-drivers mesa-libEGL mesa-libgbm libinput libseat libxkbcommon fontconfig
```

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
   scp <binary> <user>@egsob:/tmp/
   ssh <user>@egsob 'sudo install -m 0755 /tmp/<binary> /usr/local/bin/'
   ```

Shell spikes are copied the same way, without the download step: `scp spikes/<name>/run.sh <user>@egsob:~/`.

## 9. Clean-up after wave B

```sh
sudo systemctl stop egsob-spike.service
sudo rm -f /etc/systemd/system/egsob-spike.service /etc/udev/rules.d/99-egsob-cec-spike.rules
sudo rm -f /usr/local/bin/egsob-spike-*
sudo systemctl daemon-reload
sudo udevadm control --reload
```

The Pi is re-flashed with the KIWI image in Phase E.
