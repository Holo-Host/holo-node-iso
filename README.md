# holo-node-iso

Builds the Holo Sovereign Node operating system image — a customised Fedora CoreOS (FCOS) image that boots directly into the Holo node stack.

The image is built using [Butane](https://coreos.github.io/butane/) (which compiles a human-readable YAML config to Ignition JSON) and [coreos-installer](https://coreos.github.io/coreos-installer/) to produce a bootable ISO. The resulting ISO is what node operators flash to their hardware.

---

## Table of contents

1. [How it fits into the system](#how-it-fits-into-the-system)
2. [What's in the image](#whats-in-the-image)
3. [Prerequisites](#prerequisites)
4. [Repository structure](#repository-structure)
5. [Building locally](#building-locally)
6. [Ignition configuration reference](#ignition-configuration-reference)
7. [Setting up the GitHub Actions pipeline](#setting-up-the-github-actions-pipeline)
8. [Shipping a new ISO release](#shipping-a-new-iso-release)
9. [Relationship between this repo and node-onboarding](#relationship-between-this-repo-and-node-onboarding)
10. [Testing a build](#testing-a-build)
11. [Troubleshooting](#troubleshooting)

---

## How it fits into the system

```
holo-host/node-onboarding            holo-host/holo-node-iso
        │                                      │
        │  Rust source + release               │  Butane YAML + build scripts
        │  pipeline                            │
        │                                      │
        │  Publishes binaries:                 │  build.sh fetches the binary
        │  node-onboarding-x86_64    ◄─────────┤  from the latest release
        │  node-onboarding-aarch64             │
        │                                      │  Produces:
        │                                      │  holo-node-x86_64.iso
        │                                      │  holo-node-aarch64.iso
        ▼                                      ▼

                     Node operator
                     flashes ISO → hardware boots → visits http://<ip>:8080
                     → completes setup wizard → node is running
```

Once a node is running, **the node-onboarding binary updates itself automatically** from `holo-host/node-onboarding` GitHub Releases. You do not need to build or ship a new ISO to deliver software updates to running nodes. The ISO only needs to be rebuilt when:

- The FCOS base image needs updating (security patches, kernel updates)
- The Ignition/systemd configuration changes
- A new version of the node-onboarding binary needs to be baked in at first boot (i.e. for nodes being freshly provisioned — they will update themselves afterward anyway)

---

## What's in the image

| Component | Description |
|-----------|-------------|
| Fedora CoreOS (FCOS) | Minimal immutable OS base; automatic OS updates via rpm-ostree |
| `node-onboarding` binary | The onboarding + management server; fetched from GitHub Releases at ISO build time |
| `node-onboarding.service` | systemd unit that starts the server on boot |
| `install-zeroclaw.service` | systemd unit that installs the ZeroClaw agent on first boot (only runs if the operator enables the agent during onboarding) |
| `network-check.sh` | Checks for network connectivity; sets `AP_MODE=true` environment variable if only Wi-Fi is available |
| Podman + crun | Container runtime; no Docker daemon |
| `holo` user | Dedicated low-privilege user for SSH access |
| SSH hardening | Root login disabled; password auth disabled; SSH keys only |

---

## Prerequisites

Install these tools on your build machine. All are available on Linux; macOS instructions are in parentheses.

### Butane

Translates the human-readable `.bu` YAML config to Ignition JSON.

```bash
# Linux (download binary)
curl -L https://github.com/coreos/butane/releases/latest/download/butane-x86_64-unknown-linux-gnu \
  -o /usr/local/bin/butane
chmod +x /usr/local/bin/butane

# macOS
brew install butane
```

### coreos-installer

Downloads the FCOS base image and customises it with the Ignition config to produce the final ISO.

```bash
# Linux (via cargo)
cargo install coreos-installer

# Linux (Fedora/RHEL)
sudo dnf install coreos-installer

# macOS — run coreos-installer in a container (easiest)
# See "Building locally on macOS" below
```

### curl and jq

Used by `build.sh` to fetch the latest node-onboarding binary from GitHub Releases.

```bash
# Linux
sudo apt install curl jq   # Debian/Ubuntu
sudo dnf install curl jq   # Fedora

# macOS
brew install curl jq
```

---

## Repository structure

```
holo-node-iso/
├── config/
│   └── node.bu              ← Butane YAML — the human-editable config
├── scripts/
│   ├── build.sh             ← main build script
│   └── network-check.sh     ← embedded in the image; runs at boot
├── .github/
│   └── workflows/
│       └── build.yml        ← GitHub Actions: builds ISOs on push to main / on tag
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
1. Fetch the latest `node-onboarding-x86_64` binary from `holo-host/node-onboarding` GitHub Releases
2. Compile `config/node.bu` → `ignition.json` using Butane
3. Download the latest stable FCOS ISO for x86_64
4. Embed the Ignition config into the ISO using coreos-installer
5. Output `holo-node-x86_64.iso` in the project root

### Building for ARM (aarch64)

```bash
ARCH=aarch64 ./scripts/build.sh
# Outputs holo-node-aarch64.iso
```

### Building on macOS

`coreos-installer` does not run natively on macOS. Use the official container image:

```bash
docker run --rm -it \
  -v "$(pwd)":/work \
  -w /work \
  quay.io/coreos/coreos-installer:release \
  iso customize \
    --dest-ignition ignition.json \
    --dest-device /dev/null \
    --output holo-node-x86_64.iso \
    fcos-base.iso
```

`build.sh` detects macOS and falls back to this automatically if Docker is available.

### `build.sh` in full

```bash
#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-x86_64}"
FCOS_STREAM="stable"
ONBOARDING_REPO="holo-host/node-onboarding"
ASSET_NAME="node-onboarding-${ARCH}"
OUTPUT="holo-node-${ARCH}.iso"

echo "==> Fetching latest node-onboarding binary for ${ARCH}"
RELEASE_JSON=$(curl -sf \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${ONBOARDING_REPO}/releases/latest")

DOWNLOAD_URL=$(echo "$RELEASE_JSON" | \
  jq -r ".assets[] | select(.name == \"${ASSET_NAME}\") | .browser_download_url")

if [ -z "$DOWNLOAD_URL" ]; then
  echo "ERROR: Could not find asset '${ASSET_NAME}' in latest release"
  exit 1
fi

curl -L "$DOWNLOAD_URL" -o config/node-onboarding
chmod +x config/node-onboarding

echo "==> Compiling Butane config"
butane --strict config/node.bu > ignition.json

echo "==> Downloading FCOS base image"
coreos-installer download \
  --stream "$FCOS_STREAM" \
  --architecture "$ARCH" \
  --format iso \
  --decompress \
  --output fcos-base.iso

echo "==> Embedding Ignition config"
coreos-installer iso customize \
  --dest-ignition ignition.json \
  --output "$OUTPUT" \
  fcos-base.iso

echo "==> Done: ${OUTPUT}"
rm -f fcos-base.iso ignition.json config/node-onboarding
```

---

## Ignition configuration reference

`config/node.bu` is the Butane YAML that defines everything about how the node is configured at first boot. Here is the full reference for every section, including the changes required from a stock FCOS config.

### Minimal working `node.bu`

```yaml
variant: fcos
version: 1.5.0

# ── Users ─────────────────────────────────────────────────────────────────────
# The `holo` user is the only SSH-accessible user on the node.
# Root login is disabled. The node-onboarding server manages authorized_keys
# for this user via the /manage panel — no keys are baked in here.
passwd:
  users:
    - name: holo
      shell: /bin/bash
      home_dir: /home/holo
      groups:
        - systemd-journal
      # No ssh_authorized_keys here — the operator adds them via the UI.
      # If you want a fallback key for recovery, add it here:
      # ssh_authorized_keys:
      #   - "ssh-ed25519 AAAA... recovery key"

# ── Storage ───────────────────────────────────────────────────────────────────
storage:
  directories:
    # /home/holo/.ssh must exist with correct permissions before the
    # node-onboarding server tries to write authorized_keys into it.
    - path: /home/holo/.ssh
      user:
        name: holo
      group:
        name: holo
      mode: 0700

    # State directory for the onboarding server.
    - path: /etc/node-onboarding
      mode: 0700

    # ZeroClaw config directory (created by onboarding if agent is enabled,
    # but having it here avoids a permission issue if the directory doesn't exist).
    - path: /etc/zeroclaw
      mode: 0700

    # Quadlet directory — Podman reads this to create systemd units.
    - path: /etc/containers/systemd
      mode: 0755

    # EdgeNode persistent data.
    - path: /var/lib/edgenode
      mode: 0755

    # ZeroClaw workspace — the agent reads/writes mode_switch.txt here.
    - path: /var/lib/zeroclaw/workspace
      mode: 0755

  files:
    # ── SSH hardening ──────────────────────────────────────────────────────────
    # Drop-in that overrides the FCOS default sshd config.
    - path: /etc/ssh/sshd_config.d/90-holo.conf
      mode: 0600
      contents:
        inline: |
          # Holo Sovereign Node — SSH hardening
          PermitRootLogin no
          PasswordAuthentication no
          ChallengeResponseAuthentication no
          AuthorizedKeysFile .ssh/authorized_keys
          AllowUsers holo
          MaxAuthTries 3
          LoginGraceTime 30

    # ── node-onboarding binary ─────────────────────────────────────────────────
    # The build script copies the binary here before running Butane.
    # Butane embeds it as a base64-encoded file inside the Ignition JSON.
    - path: /usr/local/bin/node-onboarding
      mode: 0755
      contents:
        local: node-onboarding   # path relative to config/ directory

    # ── network-check.sh ──────────────────────────────────────────────────────
    - path: /usr/local/bin/network-check.sh
      mode: 0755
      contents:
        inline: |
          #!/bin/bash
          # Check whether we have a routable Ethernet interface.
          # If not, set AP_MODE=true so the onboarding UI shows the Wi-Fi form.
          if ip -4 route show default | grep -qv 'wl'; then
            echo "AP_MODE=false"
          else
            echo "AP_MODE=true"
          fi

# ── systemd units ─────────────────────────────────────────────────────────────
systemd:
  units:
    # ── node-onboarding.service ────────────────────────────────────────────────
    # Permanent service — runs forever, not just during onboarding.
    - name: node-onboarding.service
      enabled: true
      contents: |
        [Unit]
        Description=Holo Node Onboarding & Management Server
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        ExecStartPre=/usr/local/bin/network-check.sh
        EnvironmentFile=-/run/node-onboarding-env
        ExecStart=/usr/local/bin/node-onboarding
        Restart=always
        RestartSec=5
        StandardOutput=journal
        StandardError=journal
        SyslogIdentifier=node-onboarding
        # The service must be able to write to /etc/node-onboarding and
        # /home/holo/.ssh — do not add ReadOnlyPaths or PrivateTmp here.
        NoNewPrivileges=yes

        [Install]
        WantedBy=multi-user.target

    # ── install-zeroclaw.service ───────────────────────────────────────────────
    # Runs on first boot only if the operator enabled the AI agent.
    # node-onboarding manages whether this runs by creating/removing its
    # enablement symlink. You don't need to enable it here.
    - name: install-zeroclaw.service
      contents: |
        [Unit]
        Description=Install ZeroClaw AI Agent
        After=network-online.target
        ConditionPathExists=!/etc/zeroclaw/installed
        Before=node-onboarding.service

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/usr/local/bin/install-zeroclaw.sh
        StandardOutput=journal
        StandardError=journal

        [Install]
        WantedBy=multi-user.target

    # ── podman-auto-update.timer ───────────────────────────────────────────────
    # Automatically updates container images daily via Podman.
    - name: podman-auto-update.timer
      enabled: true
```

### Key decisions explained

**Why no SSH keys in the Ignition config?**
The node-onboarding server manages `/home/holo/.ssh/authorized_keys` at runtime via the `/manage` panel. Baking keys into Ignition means they cannot be changed without a new ISO. If you want a permanent recovery key that cannot be removed through the UI, add it to `passwd.users[holo].ssh_authorized_keys` — keys written there by Ignition are separate from the ones managed by the server.

**Why is `install-zeroclaw.service` not enabled?**
The onboarding server enables it conditionally — only if the operator opts in to the AI agent. The `ConditionPathExists=!/etc/zeroclaw/installed` guard ensures it only runs once.

**Why no firewall rules here?**
FCOS ships with `firewalld` enabled by default. Port 8080 is not open in the default zone. You should add a Butane rule to open it on the `home` or `internal` zone, not `public`. Example:

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

Create `.github/workflows/build.yml`:

```yaml
name: Build ISO

on:
  push:
    branches: [main]
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      arch:
        description: 'Architecture (x86_64 or aarch64)'
        default: 'x86_64'

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [x86_64, aarch64]

    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: |
          sudo apt-get update
          sudo apt-get install -y curl jq
          # Install Butane
          curl -L https://github.com/coreos/butane/releases/latest/download/butane-x86_64-unknown-linux-gnu \
            -o /usr/local/bin/butane && chmod +x /usr/local/bin/butane
          # Install coreos-installer
          cargo install coreos-installer

      - name: Build ISO (${{ matrix.arch }})
        env:
          ARCH: ${{ matrix.arch }}
        run: |
          chmod +x scripts/build.sh
          ./scripts/build.sh

      - name: Upload ISO artifact
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

After pushing this file, every push to `main` produces downloadable ISO artifacts on the Actions run page. Every GitHub Release automatically gets both ISOs attached.

---

## Shipping a new ISO release

### When do you need a new ISO?

| Scenario | New ISO needed? |
|----------|----------------|
| Bug fix or feature in the management UI | **No** — ship a `node-onboarding` release; nodes update themselves |
| New chat platform support | **No** — ship a `node-onboarding` release |
| FCOS base image security update | **Yes** |
| Changes to systemd units or sshd config | **Yes** |
| New version of node-onboarding for *fresh* provisioning | Optional — nodes will self-update anyway, but baking in a recent version reduces the update delay at first boot |

### Steps

1. Make your changes to `config/node.bu` (and/or `scripts/`).
2. Test locally: `./scripts/build.sh && ./scripts/build.sh ARCH=aarch64`
3. Flash and boot the x86_64 ISO in a VM to verify (see [Testing a build](#testing-a-build)).
4. Commit and push to `main`.
5. Create a GitHub Release: tag it `iso-v<date>` e.g. `iso-v2025-09-01`. GitHub Actions builds both ISOs and attaches them to the release automatically.
6. Update your node distribution page / download link to point at the new release.

---

## Relationship between this repo and node-onboarding

These two repos have a one-way dependency: `holo-node-iso` fetches a binary from `holo-host/node-onboarding` at build time. `node-onboarding` does not know about this repo.

```
holo-node-iso  ──fetches at build time──►  holo-host/node-onboarding
                                            (latest GitHub Release)
```

**Versioning:** The ISO always bakes in the latest release of `node-onboarding` at the time the ISO is built. There is no explicit version pin. If you want reproducible builds, pin to a specific release tag by modifying `build.sh`:

```bash
# Instead of fetching /releases/latest, fetch a specific version:
RELEASE_JSON=$(curl -sf \
  "https://api.github.com/repos/${ONBOARDING_REPO}/releases/tags/v5.0.0")
```

For most purposes, pinning is unnecessary — freshly-provisioned nodes running an older baked-in binary will update to the latest release within 60–90 seconds of first boot.

---

## Testing a build

### In a VM (recommended for full end-to-end testing)

```bash
# Build the ISO
./scripts/build.sh

# Boot in QEMU (requires qemu-kvm)
qemu-system-x86_64 \
  -m 4096 \
  -cpu host \
  -enable-kvm \
  -cdrom holo-node-x86_64.iso \
  -boot d \
  -nographic \
  -serial stdio
```

The console output will show the FCOS boot sequence. Once booted:
- The HDMI screen simulation will show the setup password and URL in the serial output
- Open `http://localhost:8080` (you may need to forward port 8080 from the VM)

```bash
# Port-forward if needed
qemu-system-x86_64 ... -net user,hostfwd=tcp::8080-:8080
```

### Checking the Ignition config is valid before building

```bash
butane --strict --check config/node.bu
```

This validates syntax and catches obvious errors without running a full build.

### Checking the generated Ignition JSON

```bash
butane --strict config/node.bu | python3 -m json.tool | less
```

Review the `files` section to confirm the binary and scripts are embedded correctly, and the `passwd` and `systemd` sections match your expectations.

---

## Troubleshooting

### `butane: command not found`

Install Butane — see [Prerequisites](#prerequisites).

### `coreos-installer: error: Could not download`

Check your network connection. `coreos-installer` downloads the FCOS base image (~800 MB) from Fedora's CDN. If you're behind a proxy, set `HTTPS_PROXY`.

### The ISO boots but the setup page isn't reachable

1. Check `systemctl status node-onboarding.service` on the node (SSH in using a recovery key, or attach a keyboard).
2. Confirm the node's IP with `ip addr`.
3. Check firewall: `firewall-cmd --list-all` — port 8080 should be open.
4. Check the journal: `journalctl -u node-onboarding.service -f`

### `node-onboarding` asset not found in GitHub Release

The build script fetches `node-onboarding-x86_64` or `node-onboarding-aarch64` from the latest release of `holo-host/node-onboarding`. If the release exists but the asset is missing, the GitHub Actions workflow in that repo may have failed. Check its Actions tab.

### The binary in the ISO is outdated

This is fine — the node will update itself within 60–90 seconds of first boot, pulling the latest binary from `holo-host/node-onboarding` releases. If you need a specific version baked in, pin the release tag in `build.sh` (see [Relationship between repos](#relationship-between-this-repo-and-node-onboarding)).

### Ignition fails to apply on boot

FCOS logs Ignition errors to the serial console and to `/run/ignition.json` after boot. Common causes:

- A file path referenced with `contents.local` in Butane doesn't exist in the `config/` directory at the time `butane` runs. The build script copies the binary to `config/node-onboarding` before running Butane — if this step fails, the Ignition JSON won't contain the binary.
- A `mode` value is wrong (Butane expects decimal, e.g. `0755` is octal for decimal `493` — Butane handles this correctly if you write `0755` as a YAML integer, but double-check).
- A user or group referenced in `storage.directories` doesn't exist yet. The `holo` user is created by the `passwd` section, which runs before `storage`, so this should not be an issue with this config.
