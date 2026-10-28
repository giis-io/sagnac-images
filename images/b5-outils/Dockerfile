# sagnac-b5-outils: Python 3.13.16 (standard library only), kubectl, promtool and Syft, and nothing else. Lab
# files are mounted read-only at run time; nothing is built or downloaded inside the running container.
#
# Built by build.sh (same directory). The build is reproducible:
#   - base image pinned by digest;
#   - each binary is downloaded for the target platform from its official release and checked against the
#     SHA-256 below before use (no emulation: the download stage runs on the build platform);
#   - file timestamps are set to SOURCE_DATE_EPOCH by build.sh.
ARG BASE=docker.io/library/python:3.13.16-slim@sha256:cf50a4f6ac4f026458b08d5222023d700ac806410dff5e9ca8728fa44f2b850f

FROM --platform=$BUILDPLATFORM ${BASE} AS tools
ARG TARGETARCH
# kubectl v1.37.1 (dl.k8s.io), promtool from Prometheus v3.13.4 (LTS), Syft v1.54.1 (CycloneDX SBOM).
ENV KUBECTL_VERSION=v1.37.1 PROMETHEUS_VERSION=3.13.4 SYFT_VERSION=1.54.1
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) k=65691ff77eb6fa44c908b77a1082c9f092c3b9733b5cefabec0d1104890e21a8; \
             p=87f21a66f96c597a189cef8d640e8921b621fc17a9feff707c332c4f3b3ddd56; \
             s=c069905b391cc4c20a5ba65ad5c10be2a7ba074f8ea6ad203e24d14e303dad47 ;; \
      arm64) k=ff749f4b78d9c4f1ec87307df9b50119ed819e2094aa9810cb9acffc3286c8c7; \
             p=ffa86c7d6e7f7e7dc8a79c81c5c2a6c9164464b79335f25613f4327c863b8489; \
             s=dfdf0537610113edbefe1f1fc6548bc957b2d77439636ec824fcf0e10d46d054 ;; \
      *) echo "unsupported platform: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    get() { python3 -c 'import hashlib, sys, urllib.request; d = urllib.request.urlopen(sys.argv[1], timeout=300).read(); h = hashlib.sha256(d).hexdigest(); sys.exit(f"checksum mismatch for {sys.argv[1]}: {h}") if h != sys.argv[2] else open(sys.argv[3], "wb").write(d)' "$1" "$2" "$3"; }; \
    mkdir -p /opt/sagnac/bin /tmp/t; \
    get "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" "$k" /opt/sagnac/bin/kubectl; \
    get "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-${TARGETARCH}.tar.gz" "$p" /tmp/t/prometheus.tgz; \
    tar -xzf /tmp/t/prometheus.tgz -C /tmp/t --strip-components=1 "prometheus-${PROMETHEUS_VERSION}.linux-${TARGETARCH}/promtool"; \
    mv /tmp/t/promtool /opt/sagnac/bin/promtool; \
    get "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${TARGETARCH}.tar.gz" "$s" /tmp/t/syft.tgz; \
    tar -xzf /tmp/t/syft.tgz -C /opt/sagnac/bin syft; \
    chown -R 0:0 /opt/sagnac; chmod 0755 /opt/sagnac/bin/*; rm -rf /tmp/t

FROM ${BASE}
COPY --from=tools /opt/sagnac/bin/ /usr/local/bin/
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SYFT_CHECK_FOR_APP_UPDATE=false
# Numeric unprivileged user, so that runAsNonRoot can be checked without /etc/passwd
# (Kubernetes Pod Security "restricted").
USER 65532:65532
WORKDIR /tmp
CMD ["sh", "-c", "python3 --version && kubectl version --client=true && promtool --version && syft version"]
