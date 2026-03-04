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
10. [Relationship between this repo and node-onboarding](#relationship-between-this-repo-and-node-onboarding)
11. [Testing a build](#testing-a-build)
12. [Troubleshooting](#troubleshooting)

---

## How it fits into the system

```
holo-host/node-onboarding            holo-host/holo-node-iso
        │                                      │
        │  Rust source + release               │  Butane YAML + build scripts
        │  pipeline                            │
        │                                      │
        │  Publishes binaries:                 │  Produces:
        │  node-onboarding-x86_64              │  holo-node-x86_64.iso
        │  node-onboarding-aarch64             │  holo-node-aarch64.iso
        │                                      │
        │  ◄── downloaded at first boot ───────┤  (node-setup.sh fetches the
        │       by node-setup.sh               │   binary on first boot)
        ▼                                      ▼

                     Node operator
                     flashes ISO → hardware auto-installs FCOS → reboots
                     → node-setup.sh runs → downloads node-onboarding
                     → operator visits http://<ip>:8080
                     → completes setup wizard → node is running
```

Once a node is running, **the node-onboarding binary updates itself automatically** from `holo-host/node-onboarding` GitHub Releases. You do not need to build or ship a new ISO to deliver software updates to running nodes. The ISO only needs to be rebuilt when:

- The FCOS base image needs updating (security patches, kernel updates)
- The Ignition/systemd configuration changes

---

## What's in the image

| Component | Description |
|-----------|-------------|
| Fedora CoreOS (FCOS) | Minimal immutable OS base; automatic OS updates via rpm-ostree |
| `node-setup.sh` | Inlined bash script; runs once on first boot to download `node-onboarding`. On ethernet nodes it downloads directly. On WiFi-only nodes it starts a temporary AP and serves a WiFi credentials form first. |
| `node-setup.service` | systemd unit that runs `node-setup.sh` on first boot only |
| `node-onboarding.service` | systemd unit that starts the management server after `node-setup.service` completes |
| `install-zeroclaw.service` | systemd unit that installs the ZeroClaw agent on first boot (only if operator enables it during onboarding) |
| Podman + crun | Container runtime; no Docker daemon |
| `holo` user | Dedicated low-privilege user for SSH access |
| SSH hardening | Root login disabled; password auth disabled; SSH keys only |

**Note:** The `node-onboarding` binary is not embedded in the ISO. It is downloaded at first boot by `node-setup.sh`. This keeps the ISO small and avoids the 262KB initramfs size limit imposed by `coreos-installer iso customize`.

---

## First-boot flow

### Ethernet nodes (most common)

```
ISO boots → FCOS auto-installs to internal disk → reboots from disk
→ node-setup.service starts
→ node-setup.sh detects internet via ethernet
→ downloads node-onboarding from GitHub Releases
→ node-setup.service exits
→ node-onboarding.service starts
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
→ node connects to WiFi, downloads node-onboarding
→ node-setup.service exits
→ node-onboarding.service starts
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

Note: `node-onboarding` is **not** fetched at build time. It is downloaded by `node-setup.sh` on the node's first boot.

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

The script:
- Waits for NetworkManager to be ready
- Tests for internet connectivity via `curl`
- **Ethernet path:** downloads `node-onboarding` from the latest GitHub Release and exits
- **WiFi path:** finds the WiFi interface, starts a hotspot via `nmcli`, serves a WiFi credentials form via an HTTP server loop using `nc`, connects to the provided network, then downloads `node-onboarding`
- Is guarded by `ConditionPathExists=!/usr/local/bin/node-onboarding` in its service unit — never runs again once the binary exists on disk

### systemd units

| Unit | Enabled | Purpose |
|------|---------|---------|
| `node-setup.service` | yes | Runs `node-setup.sh` once on first boot |
| `node-onboarding.service` | yes | Starts the management server; requires `node-setup.service` |
| `install-zeroclaw.service` | no | Installs ZeroClaw agent; enabled conditionally by node-onboarding |
| `podman-auto-update.timer` | yes | Daily container image updates |

### Firewall note

FCOS ships with `firewalld` enabled. Port 8080 is not open by default. If you cannot reach the setup UI, add a firewalld rule to `node.bu`:

```yaml
storage:
  files:
    - path: /etc/firewalld/zones/home.xml
      mode: 0644
      contents:
        inline: |
          <?xml version="1.0" encoding="utf-8"?>
          <zone>
            <short>Home</short>
            <service name="ssh"/>
            <port port="8080" protocol="tcp"/>
          </zone>
```

---

## Setting up the GitHub Actions pipeline

The pipeline uses two jobs to work around the fact that `coreos-installer` must be compiled from source (~3 minutes) and GitHub Actions runners don't cache between jobs by default:

- **`setup-tools`** — compiles and caches `coreos-installer`; only recompiles on a cache miss
- **`build`** — runs in parallel for x86_64 and aarch64; restores the cache from `setup-tools`

Full `build.yml`:

```yaml
name: Build ISO

on:
  push:
    branches: [main]
  release:
    types: [published]
  workflow_dispatch:

jobs:
  setup-tools:
    runs-on: ubuntu-latest
    steps:
      - name: Install Butane
        run: |
          curl -fsSL \
            https://github.com/coreos/butane/releases/latest/download/butane-x86_64-unknown-linux-gnu \
            -o /usr/local/bin/butane
          chmod +x /usr/local/bin/butane

      - name: Cache coreos-installer
        id: cache-coreos-installer
        uses: actions/cache@v4
        with:
          path: ~/.cargo/bin/coreos-installer
          key: coreos-installer-v0.25.0

      - name: Build coreos-installer
        if: steps.cache-coreos-installer.outputs.cache-hit != 'true'
        run: cargo install coreos-installer

  build:
    needs: setup-tools
    runs-on: ubuntu-latest
    timeout-minutes: 30
    strategy:
      matrix:
        arch: [x86_64, aarch64]

    steps:
      - uses: actions/checkout@v4

      - name: Free disk space
        run: |
          sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc &
          wait

      - name: Install Butane
        run: |
          curl -fsSL \
            https://github.com/coreos/butane/releases/latest/download/butane-x86_64-unknown-linux-gnu \
            -o /usr/local/bin/butane
          chmod +x /usr/local/bin/butane

      - name: Restore coreos-installer
        uses: actions/cache@v4
        with:
          path: ~/.cargo/bin/coreos-installer
          key: coreos-installer-v0.25.0

      - name: Install coreos-installer
        run: |
          if [ ! -f ~/.cargo/bin/coreos-installer ]; then
            cargo install coreos-installer
          fi
          sudo cp ~/.cargo/bin/coreos-installer /usr/local/bin/coreos-installer

      - name: Install curl and jq
        run: sudo apt-get install -y curl jq

      - name: Build ISO (${{ matrix.arch }})
        env:
          ARCH: ${{ matrix.arch }}
        run: |
          chmod +x scripts/build.sh
          ./scripts/build.sh

      - name: Upload ISO as artifact
        uses: actions/upload-artifact@v4
        with:
          name: holo-node-${{ matrix.arch }}-iso
          path: holo-node-${{ matrix.arch }}.iso
          retention-days: 30

      - name: Attach to GitHub Release
        if: github.event_name == 'release'
        uses: softprops/action-gh-release@v2
        with:
          files: holo-node-${{ matrix.arch }}.iso
```

**On artifacts vs releases:** Pushes to `main` upload ISOs as workflow artifacts (downloadable from the Actions run page for 30 days). The "Attach to GitHub Release" step is intentionally skipped — the circle-with-slash icon next to it is expected. ISOs are only attached to a release when you create one with a tag.

**On the cache:** The first run after a cache miss compiles coreos-installer (~3 minutes). Every subsequent run skips this. To upgrade coreos-installer, bump the `key` value in both cache steps.

---

## Shipping a new ISO release

### When do you need a new ISO?

| Scenario | New ISO needed? |
|----------|----------------|
| Bug fix or feature in the management UI | **No** — ship a `node-onboarding` release; nodes update within ~1 hour |
| New chat platform support | **No** — ship a `node-onboarding` release |
| FCOS base image security update | **Yes** |
| Changes to systemd units, sshd config, or `node-setup.sh` | **Yes** |
| New hardware support | **Yes** if kernel or firmware changes are needed |

### Steps

1. Make changes to `config/node.bu` and/or `scripts/build.sh`
2. Validate: `butane --strict --check config/node.bu`
3. Build and test locally: `./scripts/build.sh`
4. Boot in a VM to verify end-to-end (see [Testing a build](#testing-a-build))
5. Push to `main` — builds artifacts you can download and test
6. When ready to ship: create a GitHub Release tagged `iso-v<date>` e.g. `iso-v2026-03-04`
7. Actions builds both ISOs and attaches them to the release automatically
8. Update your node distribution page / download link to point at the new release

---

## Relationship between this repo and node-onboarding

`node-setup.sh` (embedded in the ISO) fetches `node-onboarding` from `holo-host/node-onboarding` GitHub Releases at first boot. There is no build-time dependency — the ISO contains no `node-onboarding` binary.

```
holo-node-iso  ──fetches at first boot──►  holo-host/node-onboarding
               (via node-setup.sh)          (latest GitHub Release)
```

After the initial download, `node-onboarding` updates itself automatically by polling GitHub Releases every hour. The ISO is not involved in updates after first boot.

`node-setup.sh` always fetches the latest release of `node-onboarding`. To pin to a specific version, modify the `download_binary` function in `node-setup.sh` within `config/node.bu`:

```bash
# Replace /releases/latest with /releases/tags/v5.1.0:
"https://api.github.com/repos/${ONBOARDING_REPO}/releases/tags/v5.1.0"
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

The ISO auto-installs FCOS to `test-disk.img` and reboots. After reboot, `node-setup.sh` downloads `node-onboarding` and starts the management server. Open `http://localhost:8080` to verify the setup UI.

---

## Troubleshooting

### `Error: Compressed initramfs is too large`

The Ignition config is too large for the live ISO's 262KB initramfs limit. This happens if you try to embed a binary in `node.bu` via `contents.local`. The correct approach is to keep `node.bu` binary-free and use `node-setup.sh` to download binaries at first boot. Do not add `contents.local` entries pointing to large files.

### The setup page isn't reachable after install

1. Confirm the node rebooted from its internal disk (not still running the live ISO)
2. `systemctl status node-setup.service` — did it complete successfully?
3. `ls -lh /usr/local/bin/node-onboarding` — was the binary downloaded?
4. `systemctl status node-onboarding.service` — is it running?
5. `ip addr` — what is the node's IP?
6. `firewall-cmd --list-all` — is port 8080 open?
7. `journalctl -u node-setup.service` and `journalctl -u node-onboarding.service` for full logs

### `node-setup.sh` fails to download node-onboarding

Check `journalctl -u node-setup.service`. Common causes:
- No internet at first boot (WiFi-only node where AP setup wasn't completed)
- GitHub API rate limiting (script retries automatically with backoff)
- Release asset name mismatch — assets must be named exactly `node-onboarding-x86_64` and `node-onboarding-aarch64`

### WiFi AP form doesn't load

- Navigate directly to `http://192.168.4.1:8080` — do not use HTTPS
- Confirm you are connected to the `HoloNode-Setup` WiFi network (password: `holonode`)
- Check `journalctl -u node-setup.service -f` on the node to see what the script is doing
- The HTTP server handles `GET /`, `GET /favicon.ico`, and `POST /connect`; all other paths return the form

### GitHub Actions: circle with slash next to "Attach to GitHub Release"

Expected behaviour. That step only runs on `release` events. On pushes to `main` it is skipped. ISOs are uploaded as workflow artifacts instead. To attach ISOs to a release, create a GitHub Release with a tag.

### coreos-installer takes 3+ minutes in CI

The cache is cold. This happens on the first run or after bumping the cache key. The `setup-tools` job saves the cache independently so subsequent runs skip compilation entirely.
