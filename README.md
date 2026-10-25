# Sagnac container images

Container images used by the [Sagnac](https://sagnac.fr) labs, published on the GitHub Container Registry.
Every image is built reproducibly from this repository, signed with cosign (keyless) and shipped with a
CycloneDX SBOM attestation.

| Image | Version | Platforms |
|---|---|---|
| `ghcr.io/giis-io/sagnac-agent-runtime` | `0.1.1` | `linux/amd64`, `linux/arm64` |

## sagnac-agent-runtime

A minimal Python runtime for the labs, based on the official `python:3.13.16-slim` image (Debian trixie),
pinned by digest. It adds a fixed set of Python packages, installed from wheels checked against their
SHA-256 hashes ([`requirements.txt`](images/agent-runtime/requirements.txt)):

- the MCP Python SDK (`mcp` 2.3.0);
- `jsonschema`, `pyjwt`, `cryptography`;
- the `openai` client library;
- OpenTelemetry API, SDK and OTLP exporter.

It contains no other tool. It runs as the unprivileged user `65532:65532` and is compatible with the
Kubernetes Pod Security `restricted` profile.

### Pull by digest

Always pull by digest: a tag can move, a digest cannot.

```sh
docker pull ghcr.io/giis-io/sagnac-agent-runtime@sha256:eec4e031982ea6c6f8d9009351cc8cb9655e2e4ac6886715faaaa9f5da5bb63c
```

The digest is the one of the multi-platform index; your engine picks the right platform.

### Verify the signature

Images are signed by the publication workflow of this repository, on the `main` branch, with a short-lived
certificate (Sigstore keyless signing). With [cosign](https://docs.sigstore.dev/cosign/system_config/installation/) 2.x or later:

```sh
cosign verify ghcr.io/giis-io/sagnac-agent-runtime@sha256:eec4e031982ea6c6f8d9009351cc8cb9655e2e4ac6886715faaaa9f5da5bb63c \
  --certificate-identity https://github.com/giis-io/sagnac-images/.github/workflows/publish-agent-runtime.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Any other identity means the image was not published by this repository: do not use it.

### Verify and read the SBOM

The SBOM (CycloneDX 1.7) is attached to the image as a signed attestation:

```sh
cosign verify-attestation ghcr.io/giis-io/sagnac-agent-runtime@sha256:eec4e031982ea6c6f8d9009351cc8cb9655e2e4ac6886715faaaa9f5da5bb63c \
  --type cyclonedx \
  --certificate-identity https://github.com/giis-io/sagnac-images/.github/workflows/publish-agent-runtime.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  | jq -r '.payload' | base64 -d | jq '.predicate' > sbom.cdx.json
```

### Rebuild it yourself

The build is reproducible: the same sources give the same index digest on any machine. You need Docker
with Buildx; nothing runs under emulation.

```sh
images/agent-runtime/build.sh oci sagnac-agent-runtime.tar
```

The script prints the index digest and fails if it differs from the one recorded in
[`images/agent-runtime/release`](images/agent-runtime/release).

## License

The build files in this repository are distributed under the Apache License 2.0 ([`LICENSE`](LICENSE)).

The images contain third-party software under its own licenses: the Python interpreter (PSF-2.0), Debian
packages from the base image, and the Python packages listed above (mainly MIT, Apache-2.0 and
BSD-3-Clause). The SBOM lists each component and its license.

## Security

To report a vulnerability, write to securite@sagnac.fr, or use GitHub private vulnerability reporting on
this repository. Please do not open a public issue.

Publisher: GIIS, 66 avenue des Champs-Élysées, 75008 Paris, France.
