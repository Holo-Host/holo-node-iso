#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-x86_64}"
FCOS_STREAM="stable"
OUTPUT="holo-node-${ARCH}.iso"
CONFIG_DIR="$(cd "$(dirname "$0")/../config" && pwd)"

echo "==> Compiling Butane configs"
butane --strict "${CONFIG_DIR}/node.bu" > dest-ignition.json
butane --strict "${CONFIG_DIR}/live.bu" > live-ignition.json

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
    --dest-ignition dest-ignition.json \
    --live-ignition live-ignition.json \
    --output "$OUTPUT" \
    "$FCOS_ISO"

echo "==> Cleaning up"
rm -f "$FCOS_ISO" dest-ignition.json live-ignition.json

echo ""
echo "==> Done! Output: ${OUTPUT}"
