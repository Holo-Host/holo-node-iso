
# Holo Node ISO: Development & Build Guide

This document outlines how to build, test, and ship the Holo Node operating system image. The image is a customised Fedora CoreOS (FCOS) build that boots directly into the Holo node stack.

The image is built using [Butane](https://coreos.github.io/butane/) (which compiles a human-readable YAML config to Ignition JSON) and [coreos-installer](https://coreos.github.io/coreos-installer/) to produce a bootable ISO.

----------

## Repository Structure

The core files for the build process are organized as follows:

-   `config/node.bu`: The Butane YAML file. This is the human-editable configuration.
    
-   `scripts/build.sh`: The primary bash script that executes the build.
    
-   `.github/workflows/build.yml`: The GitHub Actions pipeline for automated builds.
    

----------

## Prerequisites

To build the ISO locally, you need a few dependencies installed on your machine.

### 1. Butane

-   **Linux:** ```bash
    
    curl -L https://github.com/coreos/butane/releases/latest/download/butane-x86_64-unknown-linux-gnu -o /usr/local/bin/butane && chmod +x /usr/local/bin/butane
    
-   **macOS:** ```bash
    
    brew install butane
    

### 2. coreos-installer

-   **Linux (via cargo):** ```bash
    
    cargo install coreos-installer
    
-   **Fedora/RHEL:** ```bash
    
    sudo dnf install coreos-installer
    

### 3. curl and jq

-   **Debian/Ubuntu:** `sudo apt install curl jq`
    
-   **macOS:** `brew install curl jq`
    

----------

## Building Locally

To build the standard `x86_64` ISO, run the following from the repository root:

Bash

```
chmod +x scripts/build.sh
./scripts/build.sh

```

**What the script does:**

1.  Compiles `config/node.bu` into `ignition.json` using Butane.
    
2.  Downloads the latest stable FCOS ISO.
    
3.  Embeds the Ignition config into the ISO using `coreos-installer`.
    
4.  Outputs the final `.iso` file into the project root.
    

To build for ARM architectures, pass the architecture variable:

Bash

```
ARCH=aarch64 ./scripts/build.sh

```

----------

## Ignition Configuration Reference

The `config/node.bu` file defines exactly how the node is configured on its very first boot.

### Users & SSH

The `holo` user is the only SSH-accessible account. No SSH keys are baked in by default. If you need a permanent recovery key that the UI cannot remove, add it to the `ssh_authorized_keys` section of this file.

### Inlined Scripts

The `node-setup.sh` first-boot script is inlined directly in `node.bu`. We use a bash script instead of a baked-in binary to stay under the 262KB initramfs size limit imposed by the live ISO. Its only job is to fetch `node-manager` from GitHub Releases.

### systemd Units

**Unit**

**Type**

**Enabled**

**Description**

`network-online.target`

target

yes (drop-in)

Ensures network is online before Quadlet containers autostart.

`node-setup.service`

oneshot

yes

First-boot download of `node-manager`.

`node-manager.service`

simple

yes

Permanent management server on port 8080.

`podman-auto-update.timer`

timer

yes

Nightly container image refresh.

Podman Quadlet container units (`wind-tunnel.service`, `edgenode.service`) are written to `/etc/containers/systemd/` by node-manager at onboarding. They depend on `network-online.target` being active at boot so image pulls and network registration succeed after a reboot.

----------

## Live Install Boot Flow

When the customized ISO boots, the live environment (`config/live.bu`) runs three steps before writing to disk:

1. **Detect** — `detect-disk.sh` finds the first non-removable internal disk and writes its path to `/run/holo-install-target`.
2. **Confirm** — `confirm-install.sh` displays the target disk (device, model, size) on the console and waits for the user to type `WIPE`.
3. **Install** — Only after confirmation, `dest-device` is written to `/etc/coreos/installer.d/` and `coreos-installer` wipes and installs FCOS.

On a physical machine, UTM, or QEMU with a graphical console, the prompt appears on the active virtual terminal (`/dev/tty0` or the foreground VT from `fgconsole`). `confirm-install.sh` attaches stdin/stdout there directly so keyboard input works; it does not use systemd TTY allocation. With `-nographic -serial stdio`, the serial console is a separate path and may not receive the prompt unless the live kernel `console=` argument includes that serial port.

----------

## Testing a Build

You can validate your Butane configuration without running a full build:

Bash

```
butane --strict --check config/node.bu
butane --strict --check config/live.bu

```

To run a full end-to-end test in a virtual machine (using QEMU):

Bash

```
# Create a virtual disk
qemu-img create -f qcow2 test-disk.img 20G

# Boot the generated ISO
qemu-system-x86_64 \
  -m 4096 \
  -cpu host \
  -enable-kvm \
  -drive file=holo-node-x86_64.iso,format=raw,if=ide,media=cdrom \
  -drive file=test-disk.img,format=qcow2,if=virtio \
  -boot d \
  -nographic \
  -serial stdio \
  -net user,hostfwd=tcp::8080-:8080

```

----------

## GitHub Actions & Shipping Releases

The `.github/workflows/build.yml` workflow automatically builds ISOs on pushes to `main` and on version tags.

To publish a release ISO as a GitHub Release artifact, simply create and push a version tag:

Bash

```
git tag v1.2.0
git push origin v1.2.0

```

**When to ship a new ISO:**

You only need to rebuild and ship a new ISO when the FCOS base image requires significant security patches for _new_ hardware installs, or if the `node.bu` config changes. Running nodes update themselves via `rpm-ostree` and GitHub API polling, so they do not require new ISOs.