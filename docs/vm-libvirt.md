# EGSetOpBox VM in virt-manager (libvirt)

How to run the x86_64 EGSetOpBox image as a libvirt VM on the image host, the laptop (Chat Master D-129, D-133). The VM appears in virt-manager under the **QEMU/KVM** connection. Its disk lives in libvirt's default image directory, `/var/lib/libvirt/images`.

## 1. One-time preparation (laptop)

```sh
sudo dnf install virt-manager virt-install libvirt-daemon-kvm
sudo usermod -aG libvirt "$USER"        # log out and in again afterwards
virsh -c qemu:///system net-start default 2> /dev/null || true
virsh -c qemu:///system net-autostart default
```

Copy the repository's `os/` and `vm/` directories to the laptop, keeping them side by side.

## 2. Build the image

In fedora-devel, run `cargo build --release -p egsob-app`. Then, on the laptop:

```sh
os/build-image.sh VM
```

## 3. Create the VM (first time)

```sh
sudo cp ~/.cache/egsob/kiwi/vm/EGSetOpBox.x86_64-*.qcow2 /var/lib/libvirt/images/egsob.qcow2
sudo restorecon -v /var/lib/libvirt/images/egsob.qcow2
virt-install --connect qemu:///system --name egsob \
  --memory 4096 --vcpus 4 --cpu host-passthrough \
  --os-variant fedora-unknown --import --boot uefi \
  --disk /var/lib/libvirt/images/egsob.qcow2,format=qcow2,bus=virtio \
  --network network=default,model=virtio \
  --video virtio,accel3d=yes --graphics spice,gl.enable=yes,listen=none \
  --noautoconsole
```

## 4. First boot: initial-setup on the serial console

Open the VM in virt-manager and choose **View → Consoles → Serial 1**, or run `virsh -c qemu:///system console egsob`.

1. In **5) User creation**, set `3` (User name) to `admin`, then `5` (Password), and keep `6` (Administrator) at `[x]`.
2. In **2) Time settings**, choose Europe/Brussels.
3. Press `c` once items 2 and 5 both show `[x]`.

## 5. Use it

- **TV screen:** in virt-manager, **View → Graphical console** shows `egsob` on tty1.
- **SSH:**

  ```sh
  ip=$(virsh -c qemu:///system domifaddr egsob | awk '/ipv4/ {sub(/\/.*/, "", $4); print $4}')
  ssh admin@"$ip"
  ```

  This works from the laptop and from fedora-devel; both keys are in the image.
- **Logs:** `ssh admin@"$ip" journalctl -b -u egsob`

## 6. Replace the image after a rebuild

The new disk starts fresh, so initial-setup runs again (step 4).

```sh
virsh -c qemu:///system destroy egsob 2> /dev/null || true
sudo cp ~/.cache/egsob/kiwi/vm/EGSetOpBox.x86_64-*.qcow2 /var/lib/libvirt/images/egsob.qcow2
sudo restorecon -v /var/lib/libvirt/images/egsob.qcow2
virsh -c qemu:///system start egsob
```

## 7. Remove the VM

```sh
virsh -c qemu:///system destroy egsob 2> /dev/null || true
virsh -c qemu:///system undefine egsob --nvram
sudo rm /var/lib/libvirt/images/egsob.qcow2
```

## If the graphical console stays black

Collect `journalctl -b -u egsob` over SSH, together with the output of `virsh -c qemu:///system dumpxml egsob | grep -A3 '<video'`.
