#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-x86_64}"
FCOS_STREAM="stable"
AP_SETUP_REPO="Holo-Host/node-ap-setup"
OUTPUT="holo-node-${ARCH}.iso"
CONFIG_DIR="$(cd "$(dirname "$0")/../config" && pwd)"

fetch_asset() {
    local repo="$1"
    local asset_name="$2"
    local dest="$3"

    echo "    Fetching ${asset_name} from ${repo}"
    local release_json
    release_json=$(curl -sf \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: holo-node-iso-build" \
        "https://api.github.com/repos/${repo}/releases/latest") || {
        echo "ERROR: Failed to fetch release info for ${repo}"
        exit 1
    }

    local url
    url=$(echo "$release_json" | \
        jq -r ".assets[] | select(.name == \"${asset_name}\") | .browser_download_url")

    if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo "ERROR: Asset '${asset_name}' not found in latest release of ${repo}"
        exit 1
    fi

    echo "    Downloading from: $url"
    curl -fsSL "$url" -o "$dest"
    chmod +x "$dest"
}

echo "==> Fetching node-ap-setup binary for ${ARCH}"
fetch_asset "$AP_SETUP_REPO" "node-ap-setup-${ARCH}" "${CONFIG_DIR}/node-ap-setup"

echo "==> Stripping binary to minimise initramfs size"
BEFORE=$(ls -lh "${CONFIG_DIR}/node-ap-setup" | awk '{print $5}')
if [ "${ARCH}" = "aarch64" ]; then
    sudo apt-get install -y --no-install-recommends binutils-aarch64-linux-gnu -q
    aarch64-linux-gnu-strip "${CONFIG_DIR}/node-ap-setup"
else
    strip "${CONFIG_DIR}/node-ap-setup"
fi
AFTER=$(ls -lh "${CONFIG_DIR}/node-ap-setup" | awk '{print $5}')
echo "    Size before strip: ${BEFORE} — after: ${AFTER}"

echo "==> Compiling Butane config"
butane --strict --files-dir "${CONFIG_DIR}" "${CONFIG_DIR}/node.bu" > ignition.json

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
echo "    Downloaded: $FCOS_ISO"

echo "==> Embedding Ignition config into ISO"
coreos-installer iso customize \
    --dest-ignition ignition.json \
    --output "$OUTPUT" \
    "$FCOS_ISO"

echo "==> Cleaning up"
rm -f "$FCOS_ISO" ignition.json "${CONFIG_DIR}/node-ap-setup"

echo ""
echo "==> Done! Output: ${OUTPUT}"
