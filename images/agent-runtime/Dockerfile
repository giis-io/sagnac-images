# sagnac-agent-runtime: Python 3.13.16 with a fixed set of packages (MCP SDK, jsonschema, PyJWT, cryptography,
# openai, OpenTelemetry) and nothing else. Lab code is mounted read-only at run time; nothing is built inside
# the container.
#
# Built by build.sh (same directory). The build is reproducible:
#   - base image pinned by digest;
#   - wheels only, each checked against its SHA-256 (requirements.txt);
#   - packages are installed for the target platform from the build platform (no emulation);
#   - .pyc files use unchecked-hash invalidation (no timestamps);
#   - file timestamps are set to SOURCE_DATE_EPOCH by build.sh.
ARG BASE=docker.io/library/python:3.13.16-slim@sha256:cf50a4f6ac4f026458b08d5222023d700ac806410dff5e9ca8728fa44f2b850f

FROM --platform=$BUILDPLATFORM ${BASE} AS packages
ARG TARGETARCH
COPY requirements.txt /tmp/requirements.txt
# Debian trixie ships glibc 2.41; pip does not widen --platform to older manylinux tags by itself, hence the
# explicit list. Environment markers are evaluated as Linux, which excludes the Windows and Emscripten-only
# dependencies.
RUN set -eu; \
    case "$TARGETARCH" in amd64) arch=x86_64 ;; arm64) arch=aarch64 ;; *) echo "unsupported platform: $TARGETARCH" >&2; exit 1 ;; esac; \
    PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1 python -m pip install --quiet --no-deps --require-hashes \
        --only-binary=:all: --no-compile --target /opt/sagnac/site-packages \
        $(for v in 2_41 2_39 2_38 2_36 2_35 2_34 2_31 2_28 2_27 2_26 2_24 2_17; do printf -- '--platform manylinux_%s_%s ' "$v" "$arch"; done) \
        --platform "manylinux2014_$arch" --python-version 3.13 --implementation cp --abi cp313 \
        -r /tmp/requirements.txt; \
    rm -rf /opt/sagnac/site-packages/bin; \
    python -m compileall -q -j 1 --invalidation-mode unchecked-hash /opt/sagnac/site-packages

FROM ${BASE}
COPY --from=packages /opt/sagnac /opt/sagnac
ENV PYTHONPATH=/opt/sagnac/site-packages \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
# Numeric unprivileged user, so that runAsNonRoot can be checked without /etc/passwd
# (Kubernetes Pod Security "restricted").
USER 65532:65532
WORKDIR /tmp
CMD ["python3", "-c", "import mcp, jsonschema, jwt, cryptography, openai; print('sagnac-agent-runtime')"]
