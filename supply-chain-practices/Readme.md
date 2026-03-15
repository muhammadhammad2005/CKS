# 🔐 Supply Chain Security Practices Lab

> A hands-on implementation of container supply chain security using **Syft**, **Trivy**, **Cosign**, and **Kyverno** on a Minikube Kubernetes cluster.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Tools Used](#tools-used)
- [Project Structure](#project-structure)
- [What Was Implemented](#what-was-implemented)
  - [Task 1 — Software Bill of Materials (SBOM)](#task-1--software-bill-of-materials-sbom)
  - [Task 2 — Vulnerability Scanning](#task-2--vulnerability-scanning)
  - [Task 3 — Image Signing & Verification](#task-3--image-signing--verification)
  - [Task 4 — Kubernetes Policy Enforcement](#task-4--kubernetes-policy-enforcement)
  - [Task 5 — Monitoring & Reporting](#task-5--monitoring--reporting)
- [Key Results](#key-results)
- [Skills Demonstrated](#skills-demonstrated)

---

## Overview

This lab demonstrates a **complete container supply chain security pipeline** — from understanding what is inside an image, to scanning it for vulnerabilities, cryptographically signing it, enforcing signature policies in Kubernetes, and generating automated security reports.

Supply chain attacks (like the SolarWinds and XZ Utils incidents) target the software delivery pipeline itself. This project implements the defensive controls that prevent tampered or unvetted images from ever running in a cluster.

```
 Docker Image
      │
      ▼
 [Syft] ──────────► SBOM (what's inside?)
      │
      ▼
 [Trivy] ─────────► Vulnerability Report (is it safe?)
      │
      ▼
 [Cosign] ────────► Signed Image (can we trust it?)
      │
      ▼
 [Kyverno] ───────► Policy Enforcement (only signed images run)
      │
      ▼
 [Monitor] ───────► Continuous Reporting (stay informed)
```

---

## Tools Used

| Tool | Version | Purpose |
|------|---------|---------|
| [Syft](https://github.com/anchore/syft) | 1.x | SBOM generation |
| [Trivy](https://github.com/aquasecurity/trivy) | 0.x | Vulnerability scanning |
| [Cosign](https://github.com/sigstore/cosign) | 2.x | Image signing & verification |
| [Kyverno](https://kyverno.io) | 1.x | Kubernetes admission policy |
| Minikube | 1.x | Local Kubernetes cluster |
| Docker | 24.x | Container runtime & local registry |

---

## Project Structure

```
supply-chain-practices/
│
├── 📄 alpine-packages.txt          # Sorted package list — node:16-alpine
├── 📄 debian-packages.txt          # Sorted package list — node:16-bullseye
│
├── 📁 k8s/                         # Kubernetes manifests and scripts
│   ├── secure-pod.yaml             # Pod deployed with security context
│   ├── image-signing-policy.yaml   # Kyverno ClusterPolicy (signed images only)
│   ├── verify-k8s-images.sh        # Script to verify signatures of running pods
│   ├── generate-security-report.sh # HTML security dashboard generator
│   ├── monitor-supply-chain.sh     # Continuous monitoring script
│   ├── supply-chain-monitor.log    # Live monitoring log output
│   └── supply-chain-security-report-2026-03-15.html  # Generated HTML report
│
├── 📁 keys/                        # Cosign signing artifacts
│   ├── cosign.pub                  # Public key (used for verification)
│   ├── cosign.key                  # Private key (signing — excluded from real repos)
│   ├── secure-pipeline.sh          # End-to-end CI/CD pipeline script
│   ├── signature-verification.json # Cosign verification output
│   └── v1.0.0-sbom.json            # SBOM attached to signed image
│
├── 📁 test-app/
│   └── Dockerfile                  # Sample Dockerfile for filesystem scan
│
├── 📄 node-sbom.json               # SBOM — node:16-alpine (JSON format)
├── 📄 node-detailed-sbom.json      # SBOM — node:16-alpine (syft-json full detail)
├── 📄 node-sbom-table.txt          # SBOM — node:16-alpine (human-readable table)
├── 📄 node-ubuntu-sbom.json        # SBOM — node:16-bullseye (for comparison)
├── 📄 python-sbom-spdx.json        # SBOM — python:3.9-slim (SPDX format)
│
├── 📄 node-vuln-report.json        # Trivy full vulnerability report — node:16-alpine
├── 📄 vulnerability-summary.txt    # Trivy plain-text summary
├── 📄 node_16-alpine-scan-20260315.json    # Automated scan output
├── 📄 python_3.9-slim-scan-20260315.json   # Automated scan output
├── 📄 nginx_alpine-scan-20260315.json      # Automated scan output
│
└── 📄 scan-images.sh               # Multi-image automated scan script
```

---

## What Was Implemented

---

### Task 1 — Software Bill of Materials (SBOM)

An SBOM is a complete inventory of every package and library inside a container image. It is the foundation of supply chain security — you cannot protect what you cannot see.

**SBOMs were generated in three industry formats:**

| Format | File | Use Case |
|--------|------|----------|
| JSON | `node-sbom.json` | Machine-readable, queryable with jq |
| SPDX-JSON | `python-sbom-spdx.json` | Compliance & auditing standard |
| Table | `node-sbom-table.txt` | Human-readable review |
| Syft-JSON | `node-detailed-sbom.json` | Full metadata including licenses |

**Alpine vs Debian package footprint comparison:**

```bash
# Alpine-based image (node:16-alpine)
cat node-sbom.json | jq '.artifacts | length'
# → ~50 packages

# Debian-based image (node:16-bullseye)
cat node-ubuntu-sbom.json | jq '.artifacts | length'
# → ~400+ packages
```

> **Finding:** Alpine images carry ~8x fewer packages than Debian equivalents, drastically reducing attack surface.

**Querying the SBOM with jq:**

```bash
# List all packages and versions
cat node-sbom.json | jq -r '.artifacts[] | "\(.name) - \(.version)"'

# Find SSL-related packages
cat node-sbom.json | jq -r '.artifacts[] | select(.name | contains("ssl")) | "\(.name) - \(.version)"'

# Packages only in Alpine (not in Debian)
comm -23 alpine-packages.txt debian-packages.txt
```

---

### Task 2 — Vulnerability Scanning

**Trivy** scans images against the NVD, GitHub Advisories, and OS vendor databases to find known CVEs.

**Scans performed:**

```bash
# Scan by severity
trivy image --severity HIGH,CRITICAL node:16-alpine

# Generate machine-readable report
trivy image -f json -o node-vuln-report.json node:16-alpine

# Only show vulnerabilities that have fixes available
trivy image --ignore-unfixed node:16-alpine
```

**Vulnerability breakdown query:**

```bash
trivy image --format json node:16-alpine | \
  jq '[.Results[].Vulnerabilities[] | .Severity] | group_by(.) | map({severity: .[0], count: length})'
```

**Automated multi-image scan (`scan-images.sh`):**

```bash
#!/bin/bash
IMAGES=("node:16-alpine" "python:3.9-slim" "nginx:alpine")

for image in "${IMAGES[@]}"; do
    trivy image --format json "$image" > "${image//[:\/]/_}-scan-$(date +%Y%m%d).json"

    CRITICAL_COUNT=$(trivy image --severity CRITICAL --format json "$image" | \
      jq '[.Results[].Vulnerabilities[]] | length')

    [ "$CRITICAL_COUNT" -gt 0 ] && echo "WARNING: $image has $CRITICAL_COUNT critical vulns"
done
```

Scan outputs: `node_16-alpine-scan-20260315.json`, `python_3.9-slim-scan-20260315.json`, `nginx_alpine-scan-20260315.json`

---

### Task 3 — Image Signing & Verification

**Cosign** uses elliptic curve cryptography (ECDSA P-256) to sign container images. The signature is stored in the same registry as the image alongside its digest.

**Key pair generated:**

```bash
export COSIGN_PASSWORD=""
cosign generate-key-pair
# Creates: cosign.key (private) + cosign.pub (public)
```

**Image signed with annotations:**

```bash
cosign sign --key keys/cosign.key \
  -a "author=security-team" \
  -a "purpose=lab-demo" \
  -a "scan-status=clean" \
  --allow-insecure-registry \
  localhost:5000/node:16-alpine
```

**Signature verified:**

```bash
cosign verify --key keys/cosign.pub \
  --allow-insecure-registry \
  localhost:5000/node:16-alpine
```

Verification output saved to: `keys/signature-verification.json`

**Full CI/CD pipeline (`keys/secure-pipeline.sh`) — 6-stage process:**

```
Stage 1: Tag image
Stage 2: Generate SBOM          → v1.0.0-sbom.json
Stage 3: Vulnerability scan     → trivy (exit 1 on CRITICAL)
Stage 4: Push to registry       → localhost:5000/secure-app:v1.0.0
Stage 5: Sign image             → cosign sign
Stage 6: Attach SBOM to image   → cosign attach sbom
```

---

### Task 4 — Kubernetes Policy Enforcement

**Kyverno** is a Kubernetes-native policy engine that uses admission webhooks to intercept every pod creation request and enforce rules before anything runs.

**Pod deployed with security hardening (`k8s/secure-pod.yaml`):**

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
```

**ClusterPolicy enforces signed images only (`k8s/image-signing-policy.yaml`):**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: enforce
  rules:
  - name: check-image-signature
    match:
      any:
      - resources:
          kinds: [Pod]
          namespaces: [secure-workloads]
    verifyImages:
    - imageReferences: ["localhost:5000/*"]
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEFy21zED9Dhd5y+7UkgY81SeeNeGL
              glc033B2OH0C/wIxCAkdQYwIAFFvWLYbE2BjqbUEinuGcDEQX+dPDSIxyQ==
              -----END PUBLIC KEY-----
```

**Policy behavior:**

| Scenario | Result |
|----------|--------|
| Signed image from `localhost:5000/*` | ✅ Allowed — pod created |
| Unsigned image from `localhost:5000/*` | ❌ Blocked at admission |
| Image without matching key signature | ❌ Blocked at admission |

**Pod signature verifier script (`k8s/verify-k8s-images.sh`):**

```bash
./verify-k8s-images.sh secure-workloads
# Checks every running pod's image against cosign.pub
# Prints ✓ Verified or ✗ Failed for each
```

---

### Task 5 — Monitoring & Reporting

**Continuous monitoring (`k8s/monitor-supply-chain.sh`):**

Checks every image in the local registry for:
1. Valid Cosign signature
2. Critical vulnerability count vs configurable threshold

Output logged to `k8s/supply-chain-monitor.log`:

```
2026-03-15 12:00:01 - === Supply Chain Monitor Started ===
2026-03-15 12:00:02 - Checking: localhost:5000/node:16-alpine
2026-03-15 12:00:03 -   ✓ Signature verified
2026-03-15 12:00:45 -   ✓ Vulnerability check passed (2 critical)
2026-03-15 12:00:46 - Checking: localhost:5000/secure-app:v1.0.0
2026-03-15 12:00:47 -   ✓ Signature verified
2026-03-15 12:01:20 -   ✓ Vulnerability check passed (2 critical)
2026-03-15 12:01:21 - === Monitoring Complete ===
```

**HTML Security Dashboard (`k8s/supply-chain-security-report-2026-03-15.html`):**

Auto-generated report containing:
- SBOM summary table with package counts per image
- Vulnerability counts broken down by severity (CRITICAL / HIGH / MEDIUM)
- Image signing status (Verified / Not Signed) per image
- Live Kubernetes pod status across all namespaces

---

## Key Results

| Security Control | Status | Detail |
|-----------------|--------|--------|
| SBOM — node:16-alpine | ✅ Complete | JSON, SPDX, Table, Detailed formats |
| SBOM — python:3.9-slim | ✅ Complete | SPDX-JSON format |
| Vulnerability scan — node | ✅ Complete | Full JSON report + plain text summary |
| Vulnerability scan — python | ✅ Complete | Automated scan output |
| Vulnerability scan — nginx | ✅ Complete | Automated scan output |
| Image signing — node:16-alpine | ✅ Signed & Verified | With author/purpose annotations |
| Image signing — secure-app:v1.0.0 | ✅ Signed & Verified | Via CI/CD pipeline |
| SBOM attestation | ✅ Attached | SBOM attached to signed image digest |
| Kubernetes namespace | ✅ Created | `secure-workloads` namespace |
| Pod security context | ✅ Applied | Non-root, no privilege escalation |
| Kyverno policy | ✅ Deployed | Blocks unsigned images at admission |
| Monitoring script | ✅ Running | Signature + vuln threshold checks |
| HTML security report | ✅ Generated | `supply-chain-security-report-2026-03-15.html` |

---

## Skills Demonstrated

- **SBOM generation** in multiple industry-standard formats (CycloneDX, SPDX, Syft-JSON)
- **CVE analysis** — filtering, counting, and identifying fixable vulnerabilities by severity
- **Asymmetric cryptography** — ECDSA key pair generation, image signing, and signature verification
- **Registry operations** — pushing images, storing signatures as OCI artifacts
- **Kubernetes security** — namespace isolation, pod security contexts, admission webhooks
- **Policy as code** — writing and applying Kyverno ClusterPolicy with image verification rules
- **CI/CD security integration** — building a gated pipeline that fails on critical vulnerabilities
- **Automated reporting** — shell scripting to generate structured HTML dashboards and log files

---

> **Environment:** Ubuntu 22.04 | Minikube v1.x | Docker 24.x | AWS EC2
