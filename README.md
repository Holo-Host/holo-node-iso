# holo-node-iso

Builds the Holo Node operating system image — a customised Fedora CoreOS (FCOS) image that boots directly into the Holo node stack.

The image is built using [Butane](https://coreos.github.io/butane/) (which compiles a human-readable YAML config to Ignition JSON) and [coreos-installer](https://coreos.github.io/coreos-installer/) to produce a bootable ISO. The resulting ISO is what node operators flash to their hardware.

---

## Table of contents

1. [How it fits into the system](#how-it-fits-into-the-system)
2. [What's in the image](#whats-in-the-image)
3. [First-boot flow](#first-boot-flow)
4. [Prerequisites](#prerequisites)
5. [Repository structure](#repository-structure)
6. [Building locally](#building-locally)
7. [Ignition configuration reference](#ignition-configuration-reference)
8. [Setting up the GitHub Actions pipeline](#setting-up-the-github-actions-pipeline)
9. [Shipping a new ISO release](#shipping-a-new-iso-release)
10. [Relationship between this repo and node-manager](#relationship-between-this-repo-and-node-manager)
11. [Testing a build](#testing-a-build)
12. [Troubleshooting](#troubleshooting)

---

## How it fits into the system

```
holo-host/node-manager               holo-host/holo-node-iso
        │                                      │
        │  Rust source + release               │  Butane YAML + build scripts
        │  pipeline                            │
        │                                      │
        │  Publishes binaries:                 │  Produces:
        │  node-manager-x86_64                 │  holo-node-x86_64.iso
        │  node-manager-aarch64                │  holo-node-aarch64.iso
        │                                      │
        │  ◄── downloaded at first boot ───────┤  (node-setup.sh fetches the
        │       by node-setup.sh               │   binary on first boot)
        ▼                                      ▼

                     Node operator
                     flashes ISO → hardware auto-installs FCOS → reboots
                     → node-setup.sh runs → downloads node-manager
                     → operator visits http://<ip>:8080
                     → completes setup wizard → node is running
```

Once a node is running, **the node-manager binary updates itself automatically** from `holo-host/node-manager` GitHub Releases. You do not need to build or ship a new ISO to deliver software updates to running nodes. The ISO only needs to be rebuilt when:

- The FCOS base image needs updating (security patches, kernel updates)
- The Ignition/systemd configuration changes

---

## What's in the image

| Component | Description |
|-----------|-------------|
| Fedora CoreOS (FCOS) | Minimal immutable OS base; automatic OS updates via rpm-ostree |
| `node-setup.sh` | Inlined bash script; runs once on first boot to download `node-manager`. On ethernet nodes it downloads directly. On WiFi-only nodes it first starts a captive-portal AP to collect credentials. |
| `node-manager.service` | Permanent systemd service; starts after `node-setup.service` exits |
| `openclaw-daemon.service` | OpenClaw AI agent service; started by `node-manager` after operator enables it |
| `openclaw-update.service` / `.timer` | Hourly timer that pulls the latest OpenClaw fork binary to `/usr/local/bin/openclaw` |
| `podman-auto-update.timer` | Nightly container image refresh via `io.containers.autoupdate=registry` labels |
| SSH hardening | Root login disabled; password auth disabled; `holo` is the only SSH-accessible user |

There is no build-time dependency on `node-manager` — the ISO contains no management binary.

---

## First-boot flow

### Ethernet nodes (most common)

```
ISO boots → FCOS auto-installs to internal disk → reboots from disk
→ node-setup.service starts
→ node-setup.sh detects internet via ethernet
→ downloads node-manager from GitHub Releases
→ node-setup.service exits
→ node-manager.service starts
→ operator opens http://<node-ip>:8080 → completes setup
→ node-setup.service never runs again (binary now exists on disk)
```

### WiFi-only nodes

```
ISO boots → FCOS auto-installs to internal disk → reboots from disk
→ node-setup.service starts
→ node-setup.sh detects no internet
→ starts WiFi AP: SSID "HoloNode-Setup", password "holonode"
→ serves WiFi credentials form at http://192.168.4.1:8080
→ operator connects phone/laptop to HoloNode-Setup
→ operator opens http://192.168.4.1:8080
→ operator enters home WiFi SSID and password → submits
→ node connects to WiFi, downloads node-manager
→ node-setup.service exits
→ node-manager.service starts
→ operator connects to home network, opens http://<node-ip>:8080
→ completes setup
```

---

## Prerequisites

### Butane

```bash
# Linux
curl -L https://github.com/coreos/butane/releases/latest/download/butane-x86_64-unknown-linux-gnu \
  -o /usr/local/bin/butane
chmod +x /usr/local/bin/butane

# macOS
brew install butane
```

### coreos-installer

```bash
# Linux (via cargo — takes ~3 minutes to compile)
cargo install coreos-installer

# Linux (Fedora/RHEL)
sudo dnf install coreos-installer
```

### curl and jq

```bash
sudo apt install curl jq   # Debian/Ubuntu
sudo dnf install curl jq   # Fedora
brew install curl jq       # macOS
```

---

## Repository structure

```
holo-node-iso/
├── config/
│   └── node.bu              ← Butane YAML — the human-editable config
├── scripts/
│   └── build.sh             ← main build script
├── .github/
│   └── workflows/
│       └── build.yml        ← GitHub Actions: builds ISOs on push/release
└── README.md
```

---

## Building locally

### Quick start

```bash
git clone https://github.com/holo-host/holo-node-iso
cd holo-node-iso
chmod +x scripts/build.sh
./scripts/build.sh
```

This will:
1. Compile `config/node.bu` → `ignition.json` using Butane
2. Download the latest stable FCOS ISO for x86_64
3. Embed the Ignition config into the ISO using coreos-installer
4. Output `holo-node-x86_64.iso` in the project root

Note: `node-manager` is **not** fetched at build time. It is downloaded by `node-setup.sh` on the node's first boot.

### Building for ARM (aarch64)

```bash
ARCH=aarch64 ./scripts/build.sh
# Outputs holo-node-aarch64.iso
```

### `build.sh` in full

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-x86_64}"
FCOS_STREAM="stable"
OUTPUT="holo-node-${ARCH}.iso"
CONFIG_DIR="$(cd "$(dirname "$0")/../config" && pwd)"

echo "==> Compiling Butane config"
butane --strict "${CONFIG_DIR}/node.bu" > ignition.json

echo "==> Downloading FCOS ${FCOS_STREAM} base image (${ARCH})"
coreos-installer download \
    --stream "$FCOS_STREAM" \
    --architecture "$ARCH" \
    --format iso \
    --decompress

FCOS_ISO=$(ls fedora-coreos-*.iso 2>/dev/null | head -1)
if [ -z "$FCOS_ISO" ]; then
    echo "ERROR: Could not find downloaded FCOS ISO"
    exit 1
fi

echo "==> Embedding Ignition config into ISO"
coreos-installer iso customize \
    --dest-ignition ignition.json \
    --output "$OUTPUT" \
    "$FCOS_ISO"

rm -f "$FCOS_ISO" ignition.json
echo "==> Done! Output: ${OUTPUT}"
```

---

## Ignition configuration reference

`config/node.bu` defines everything about how the node is configured at first boot.

### Users

```yaml
passwd:
  users:
    - name: holo
      shell: /bin/bash
      home_dir: /home/holo
      groups:
        - systemd-journal
```

The `holo` user is the only SSH-accessible account. No SSH keys are baked in — the operator adds them via the management UI after setup. To add a permanent recovery key that the UI cannot remove, add it to `ssh_authorized_keys` here.

### node-setup.sh

The first-boot script is inlined directly in `node.bu` via `contents.inline`. It is a bash script, not a binary — this is intentional. Any binary large enough to be useful would exceed the 262KB initramfs size limit imposed by `coreos-installer iso customize`. A bash script compresses to a few KB.

The script's only job is to download `node-manager` from the latest GitHub Release and install it to `/usr/local/bin/node-manager`. It runs exactly once, gated by `ConditionPathExists=!/usr/local/bin/node-manager` in the systemd unit.

### systemd units

| Unit | Type | Enabled | Description |
|------|------|---------|-------------|
| `node-setup.service` | oneshot | yes | First-boot download of `node-manager` |
| `node-manager.service` | simple | yes | Permanent management server on :8080 |
| `openclaw-daemon.service` | simple | no | OpenClaw AI agent; started by node-manager |
| `openclaw-update.service` | oneshot | no | Pulls latest OpenClaw fork binary |
| `openclaw-update.timer` | timer | yes | Triggers openclaw-update.service every hour |
| `podman-auto-update.timer` | timer | yes | Nightly container image refresh |

---

## Setting up the GitHub Actions pipeline

The `.github/workflows/build.yml` workflow builds ISOs automatically on push to `main` and on version tags. It requires no secrets — the build is entirely public tooling (Butane + coreos-installer).

To publish a release ISO as a GitHub Release artifact, create a version tag:

```bash
git tag v1.2.0
git push origin v1.2.0
```

GitHub Actions will build both architectures and attach them to the release.

---

## Shipping a new ISO release

Rebuild and ship a new ISO when:

- The FCOS base image has had significant security patches and you want to bake those in for fresh installs (running nodes update themselves via rpm-ostree; this is for new hardware)
- The `node.bu` Ignition config has changed (new systemd units, updated `node-setup.sh`, changed SSH hardening)

**Running nodes do not need a new ISO** — `node-manager` self-updates from GitHub Releases, and `openclaw-update.timer` updates the OpenClaw fork binary hourly.

---

## Relationship between this repo and node-manager

There is no build-time dependency — the ISO contains no `node-manager` binary.

```
holo-node-iso  ──fetches at first boot──►  holo-host/node-manager
               (via node-setup.sh)          (latest GitHub Release)
```

After the initial download, `node-manager` updates itself automatically by polling GitHub Releases every hour. The ISO is not involved in updates after first boot.

`node-setup.sh` always fetches the latest release of `node-manager`. To pin to a specific version, modify the `download_binary` function in `node-setup.sh` within `config/node.bu`:

```bash
# Replace /releases/latest with /releases/tags/v5.1.0:
"https://api.github.com/repos/${MANAGER_REPO}/releases/tags/v5.1.0"
```

For most purposes pinning is unnecessary — a node running an older binary will self-update within ~60 seconds of coming online.

---

## Testing a build

### Validate the Butane config without building

```bash
butane --strict --check config/node.bu
```

### Inspect the generated Ignition JSON

```bash
butane --strict config/node.bu | python3 -m json.tool | less
```

Check the `passwd`, `storage`, and `systemd` sections. Confirm `node-setup.sh` is present under `storage.files`.

### Full end-to-end test in a VM

```bash
# Create a virtual disk to install to
qemu-img create -f qcow2 test-disk.img 20G

# Build the ISO
./scripts/build.sh

# Boot
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

The ISO auto-installs FCOS to `test-disk.img` and reboots. After reboot, `node-setup.sh` downloads `node-manager` and starts the management server. Open `http://localhost:8080` to verify the setup UI.

---

## Troubleshooting

### `Error: Compressed initramfs is too large`

The Ignition config is too large for the live ISO's 262KB initramfs limit. This happens if you try to embed a binary in `node.bu` via `contents.local`. The correct approach is to keep `node.bu` binary-free and use `node-setup.sh` to download binaries at first boot. Do not add `contents.local` entries pointing to large files.

### The setup page isn't reachable after install

1. Confirm the node rebooted from its internal disk (not still running the live ISO)
2. `systemctl status node-setup.service` — did it complete successfully?
3. `ls -lh /usr/local/bin/node-manager` — was the binary downloaded?
4. `systemctl status node-manager.service` — is it running?
5. `ip addr` — what is the node's IP?
6. `firewall-cmd --list-all` — is port 8080 open?
7. `journalctl -u node-setup.service` and `journalctl -u node-manager.service` for full logs

### `node-setup.sh` fails to download node-manager

Check `journalctl -u node-setup.service`. Common causes:

- No internet connectivity at first boot — confirm ethernet is plugged in, or complete the WiFi AP flow
- GitHub API rate limit — unlikely for a single node, but possible in CI/test environments
- Firewall blocking outbound HTTPS — ensure port 443 is open

### node-manager won't start

```bash
journalctl -u node-manager.service -n 50 --no-pager
```

If the binary exists but the service fails immediately, check that it is executable (`chmod +x /usr/local/bin/node-manager`) and that it is the correct architecture (`file /usr/local/bin/node-manager`).
