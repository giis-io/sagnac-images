#!/bin/sh
# Reproducible build of ghcr.io/giis-io/sagnac-b5-outils. Signs nothing: signing and the SBOM are done
# by .github/workflows/publish-b5-outils.yml.
#
#   build.sh digest                 print the expected index digest (from the release file)
#   build.sh oci <file.tar>         build an OCI archive (amd64 + arm64 index); print the index digest
#   build.sh docker                 load the image into the local engine; print the index digest
#   build.sh registry <repository>  push BY DIGEST, then add the version tag; print the index digest
#
# Reproducibility: the build context is this directory only; SOURCE_DATE_EPOCH is fixed (SOURCE_DATE_EPOCH
# file) and applied to the context files; BuildKit is pinned by digest (docker-container driver); no
# provenance or SBOM is embedded (they would carry the build time); layer timestamps are rewritten; OCI media
# types. Two builds on two machines give the same index digest. "oci", "docker" and "registry" refuse a
# digest that differs from the release file (unless SAGNAC_IMAGE_UNPINNED=1, to compute a new one).
# Exit codes: 0 success; 1 digest mismatch or build failure; 2 usage.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
RELEASE="$HERE/release"
BUILDER="${SAGNAC_BUILDER:-sagnac-images}"
# BuildKit v0.33.1 (2026-09-30).
BUILDKIT=moby/buildkit:v0.33.1@sha256:cec9f139f45e93c5c69c60f8b07cfad9f43f4ef6b6a6cd917527fea5ff2e3dea
PLATFORMS=linux/amd64,linux/arm64
NAME=ghcr.io/giis-io/sagnac-b5-outils
SOURCE=https://github.com/giis-io/sagnac-images
TITLE=sagnac-b5-outils
DESCRIPTION="Tools image for Sagnac labs (B5): Python 3.13, kubectl, promtool and Syft. Reproducible, signed, non-root."
LICENSES="PSF-2.0 AND Apache-2.0"
SOURCE_DATE_EPOCH=$(tr -d ' \n' <"$HERE/SOURCE_DATE_EPOCH")
export SOURCE_DATE_EPOCH

usage() { sed -n '2,16p' "$0" >&2; exit 2; }

sha256() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1; }

field() { sed -n "s/^$1=//p" "$RELEASE" | head -n 1; }
version() { field version; }
expected() { field digest | sed -n 's/^\(sha256:[0-9a-f]\{64\}\)$/\1/p'; }

builder() {
    if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
        docker buildx create --name "$BUILDER" --driver docker-container --driver-opt "image=$BUILDKIT" >/dev/null
    fi
    docker buildx inspect --bootstrap "$BUILDER" >/dev/null
}

# build OUTPUT: print the digest of the resulting index.
build() {
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    mkdir "$tmp/context"
    cp "$HERE/Dockerfile" "$tmp/context/"
    stamp=$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%d%H%M.%S 2>/dev/null || date -u -r "$SOURCE_DATE_EPOCH" +%Y%m%d%H%M.%S)
    find "$tmp/context" -exec env TZ=UTC touch -h -t "$stamp" {} +
    builder
    v=$(version)
    [ -n "$v" ] || { echo "release file: version missing" >&2; exit 1; }
    # Labels go into each image config; the index annotations are what the registry shows for a
    # multi-platform image.
    docker buildx build --builder "$BUILDER" --no-cache --pull --platform "$PLATFORMS" \
        --provenance=false --sbom=false --build-arg SOURCE_DATE_EPOCH \
        --label "org.opencontainers.image.source=$SOURCE" \
        --label "org.opencontainers.image.title=$TITLE" \
        --label "org.opencontainers.image.description=$DESCRIPTION" \
        --label "org.opencontainers.image.version=$v" \
        --label "org.opencontainers.image.vendor=GIIS" \
        --label "org.opencontainers.image.licenses=$LICENSES" \
        --annotation "index:org.opencontainers.image.source=$SOURCE" \
        --annotation "index:org.opencontainers.image.description=$DESCRIPTION" \
        --annotation "index:org.opencontainers.image.licenses=$LICENSES" \
        --output "$1,oci-mediatypes=true,rewrite-timestamp=true" \
        --metadata-file "$tmp/meta.json" "$tmp/context" >&2
    d=$(sed -n 's/.*"containerimage\.digest": *"\(sha256:[0-9a-f]\{64\}\)".*/\1/p' "$tmp/meta.json" | head -n 1)
    [ -n "$d" ] || { echo "digest missing from buildx metadata" >&2; exit 1; }
    echo "$d"
}

check() {
    e=$(expected)
    if [ "${SAGNAC_IMAGE_UNPINNED:-}" = 1 ]; then return 0; fi
    [ -n "$e" ] || { echo "release file: digest missing" >&2; exit 1; }
    [ "$1" = "$e" ] || { echo "build not reproducible: got $1, release file expects $e" >&2; exit 1; }
}

command="${1:-}"; [ $# -gt 0 ] && shift
case "$command" in
    digest) expected ;;
    oci)
        [ $# -eq 1 ] || usage
        d=$(build "type=oci,dest=$1,name=$NAME:$(version)"); check "$d"; echo "$d" ;;
    docker)
        command -v docker >/dev/null || { echo "docker not found" >&2; exit 1; }
        t=$(mktemp -d); d=$(build "type=oci,dest=$t/image.tar,name=$NAME:$(version)"); check "$d"
        docker load -q -i "$t/image.tar" >&2; rm -rf "$t"
        docker image inspect "$NAME@$d" >/dev/null 2>&1 || { echo "loaded image not found as $NAME@$d (engine without containerd image store?)" >&2; exit 1; }
        echo "$d" ;;
    registry)
        [ $# -eq 1 ] || usage
        # First build to a local archive: nothing is pushed unless it matches the release file.
        d=$(build "type=oci,dest=$(mktemp -u).tar"); check "$d"
        p=$(build "type=registry,name=$1,push-by-digest=true"); check "$p"
        [ "$d" = "$p" ] || { echo "build not reproducible between two runs: $d != $p" >&2; exit 1; }
        docker buildx imagetools create --builder "$BUILDER" -t "$1:$(version)" "$1@$p" >&2
        # The tag must point to the very index that was checked (its digest is the SHA-256 of the raw manifest).
        t="sha256:$(docker buildx imagetools inspect --builder "$BUILDER" --raw "$1:$(version)" | sha256)"
        [ "$t" = "$p" ] || { echo "tag $1:$(version) points to $t, not $p" >&2; exit 1; }
        echo "$p" ;;
    *) usage ;;
esac
