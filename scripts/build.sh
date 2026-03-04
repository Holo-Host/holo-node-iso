#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-x86_64}"
FCOS_STREAM="stable"
ONBOARDING_REPO="Holo-Host/node-onboarding"
ASSET_NAME="node-onboarding-${ARCH}"
OUTPUT="holo-node-${ARCH}.iso"
CONFIG_DIR="$(dirname "$0")/../config"

echo "==> Fetching latest node-onboarding binary for ${ARCH}"
RELEASE_JSON=$(curl -sf \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: holo-node-iso-build" \
  "https://api.github.com/repos/${ONBOARDING_REPO}/releases/latest") || {
  echo "ERROR: Failed to fetch release info from GitHub API."
  echo "Check that holo-host/node-onboarding has at least one published release with binary assets."
  exit 1
}

DOWNLOAD_URL=$(echo "$RELEASE_JSON" | \
  jq -r ".assets[] | select(.name == \"${ASSET_NAME}\") | .browser_download_url")

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
  echo "ERROR: Could not find asset '${ASSET_NAME}' in latest release."
  echo "Make sure the node-onboarding release workflow has run successfully."
  exit 1
fi

echo "    Downloading from: $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "${CONFIG_DIR}/node-onboarding"
chmod +x "${CONFIG_DIR}/node-onboarding"

echo "==> Compiling Butane config"
sed -i 's/\r//' "${CONFIG_DIR}/node.bu"
butane --strict -d "${CONFIG_DIR}" "${CONFIG_DIR}/node.bu" > ignition.json

echo "==> Downloading FCOS ${FCOS_STREAM} base image (${ARCH})"
coreos-installer download \
  --stream "$FCOS_STREAM" \
  --architecture "$ARCH" \
  --format iso \
  --decompress

# coreos-installer names the file automatically, e.g.:
# fedora-coreos-42.20250301.3.0-live.aarch64.iso
# Find whatever it downloaded
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
rm -f "$FCOS_ISO" ignition.json "${CONFIG_DIR}/node-onboarding"

echo ""
echo "==> Done! Output: ${OUTPUT}"