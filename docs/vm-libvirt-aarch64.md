# Pi image in an aarch64 libvirt VM

How to boot the Raspberry Pi image as an emulated aarch64 libvirt VM on the laptop, to check the image without the Pi (Chat Master D-117, D-142). The CPU is emulated (TCG), so everything is slow; the first boot can take 10–20 minutes. This only checks the image's userspace: it does not exercise the Pi firmware, U-Boot, video decoding or HDMI-CEC.

## 1. One-time preparation (laptop)

Do section 1 of `docs/vm-libvirt.md` first (libvirt group, default network). Then:

```sh
rpm -q qemu-system-aarch64-core edk2-aarch64 || sudo dnf install qemu-system-aarch64-core edk2-aarch64
```

## 2. Build the image

```sh
os/build-image.sh Pi
```

This needs a successful `release.yml` run for the aarch64 binary.

## 3. Create the VM

```sh
img="$(ls ~/.cache/egsob/kiwi/pi/EGSetOpBox.aarch64-*.raw* | head -1)"
case "${img}" in
	*.xz) xz -dc "${img}" | sudo dd of=/var/lib/libvirt/images/egsob-pi.raw bs=4M status=progress ;;
	*) sudo cp "${img}" /var/lib/libvirt/images/egsob-pi.raw ;;
esac
sudo restorecon -v /var/lib/libvirt/images/egsob-pi.raw
virt-install --connect qemu:///system --name egsob-pi \
  --virt-type qemu --arch aarch64 --machine virt --cpu cortex-a72 \
  --memory 4096 --vcpus 4 --os-variant fedora-unknown --import --boot uefi \
  --disk /var/lib/libvirt/images/egsob-pi.raw,format=raw,bus=virtio \
  --network network=default,model=virtio \
  --video virtio --graphics spice,listen=none \
  --input keyboard,bus=usb --input tablet,bus=usb \
  --noautoconsole
```

## 4. First boot: initial-setup on the graphical console

The Pi image uses `console=tty1`, so initial-setup appears in virt-manager's **graphical console**, not on a serial console. Open the VM `egsob-pi` there.

1. In **5) User creation**, set `3` (User name) to `admin`, then `5` (Password), and keep `6` (Administrator) at `[x]`.
2. In **2) Time settings**, choose Europe/Brussels.
3. Press `c` once items 2 and 5 both show `[x]`.

After setup, `egsob` takes over tty1. Without 3D acceleration it may not draw anything; that is expected here.

## 5. Check SSH

```sh
ip=$(virsh -c qemu:///system domifaddr egsob-pi | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4}')
ssh admin@"$ip" 'hostnamectl; uname -m'
```

`uname -m` must print `aarch64`.

## 6. Remove the VM

```sh
virsh -c qemu:///system destroy egsob-pi 2> /dev/null || true
virsh -c qemu:///system undefine egsob-pi --nvram
sudo rm /var/lib/libvirt/images/egsob-pi.raw
```
