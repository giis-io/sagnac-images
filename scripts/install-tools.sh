#!/bin/sh
# Release tools, pinned by version and checked by SHA-256. Linux amd64 or arm64 (detected).
#
#   install-tools.sh <dir>      install cosign and syft into <dir> (add it to PATH)
set -eu

DEST="${1:?destination directory}"
COSIGN_VERSION=3.1.3
# syft 1.52.0 (2026-09-17): CycloneDX 1.7 SBOM of the image (cyclonedx-json@1.7).
SYFT_VERSION=1.52.0
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64
    COSIGN_SHA256=4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71
    SYFT_SHA256=caeedb81fb0491615f1ebd1761e4145d41ee86dd2cc7bf80669f9f5ad9d6133d ;;
  aarch64|arm64) ARCH=arm64
    COSIGN_SHA256=c5d324e091826b0d7a78eb16fef316450b4eb9aaec045611c08ba06f5e73220a
    SYFT_SHA256=c46d5e4c28e12aa4c5becfaa343ef1c7f89045b6b895f2c21d471c62db09c706 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 2 ;;
esac

install -d "$DEST"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

curl -fsSL --proto '=https' -o "$tmp/cosign" \
  "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}"
echo "${COSIGN_SHA256}  $tmp/cosign" | sha256sum -c - >/dev/null || { echo "cosign checksum mismatch" >&2; exit 1; }
install -m 0755 "$tmp/cosign" "$DEST/cosign"

curl -fsSL --proto '=https' -o "$tmp/syft.tgz" \
  "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${ARCH}.tar.gz"
echo "${SYFT_SHA256}  $tmp/syft.tgz" | sha256sum -c - >/dev/null || { echo "syft checksum mismatch" >&2; exit 1; }
tar -xzf "$tmp/syft.tgz" -C "$tmp" syft
install -m 0755 "$tmp/syft" "$DEST/syft"

"$DEST/cosign" version >/dev/null && "$DEST/syft" version >/dev/null
echo "cosign ${COSIGN_VERSION}, syft ${SYFT_VERSION} in $DEST" >&2
