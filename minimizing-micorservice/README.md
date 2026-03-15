# Lab 16: Minimizing Microservice Vulnerabilities

> **Platform:** Minikube on Ubuntu (AWS EC2)  
> **Kubernetes Version:** v1.35.1  
> **Date Completed:** March 15, 2026  
> **Certification Track:** Certified Kubernetes Security Specialist (CKS)

---

## Table of Contents

1. [Lab Overview](#lab-overview)
2. [Lab Environment](#lab-environment)
3. [Task 1 — Pod Security Standards](#task-1--pod-security-standards)
4. [Task 2 — Minimal Base Images](#task-2--minimal-base-images)
5. [Task 3 — gVisor Application Sandboxing](#task-3--gvisor-application-sandboxing)
6. [Task 4 — Security Analysis and Report](#task-4--security-analysis-and-report)
7. [Key Concepts Summary](#key-concepts-summary)
8. [Troubleshooting Notes](#troubleshooting-notes)
9. [File Structure](#file-structure)

---

## Lab Overview

This lab demonstrates three core security hardening techniques for Kubernetes microservices:

| Technique | Purpose | Tool Used |
|---|---|---|
| Pod Security Standards | Prevent privilege escalation in pods | Kubernetes PSS labels |
| Minimal Base Images | Reduce container attack surface | Alpine Linux vs python:3.11 |
| Application Sandboxing | Isolate container syscalls from host kernel | gVisor (runsc) |

These three layers form a **defense-in-depth** strategy — each addresses a different attack vector, and together they significantly reduce the risk of container compromise and host escape.

---

## Lab Environment

- **Cluster:** Minikube (single node)
- **Container Runtime:** containerd (required for gVisor)
- **Node:** `minikube` at `192.168.49.2`
- **Namespace:** `secure-microservices`
- **Working Directory:** `~/lab/minimizing-micorservice/`

### Directory structure after lab completion

```
~/lab/minimizing-micorservice/
├── compliant-app.yaml
├── non-compliant-app.yaml
├── performance-test.sh
└── microservice-app/
    ├── app.py
    ├── requirements.txt
    ├── Dockerfile.standard
    ├── Dockerfile.alpine
    ├── minimal-app-deployment.yaml
    ├── sandboxed-app-deployment.yaml
    ├── gvisor-runtime-class.yaml
    ├── network-policy.yaml
    ├── generate-security-report.sh
    └── security-report.txt
```

---

## Task 1 — Pod Security Standards

### What are Pod Security Standards?

Kubernetes Pod Security Standards (PSS) are built-in policies that control what a pod is allowed to do at the namespace level. There are three tiers:

| Policy | Description |
|---|---|
| **Privileged** | No restrictions — maximum permissions |
| **Baseline** | Prevents known privilege escalations |
| **Restricted** | Heavily locked down, follows hardening best practices |

In this lab we use **Baseline**, which is the recommended starting point for most production workloads. It blocks the most dangerous misconfigurations without breaking standard applications.

### Step 1: Check Kubernetes version

```bash
kubectl version --short
```

This confirms you have a v1.28+ cluster, which is required for stable PSS support.

### Step 2: Create and label the namespace

```bash
kubectl create namespace secure-microservices

kubectl label namespace secure-microservices \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/warn=baseline
```

**What these labels do:**

- `enforce` — Pods that violate the policy are **rejected** outright
- `audit` — Violations are **logged** to the audit log but not blocked
- `warn` — Violations trigger **user-facing warnings** but are not blocked

Setting all three to `baseline` means you get warnings AND enforcement.

### Step 3: Deploy a non-compliant app (to observe blocking)

```yaml
# non-compliant-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: non-compliant-app
  namespace: secure-microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: non-compliant-app
  template:
    metadata:
      labels:
        app: non-compliant-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        securityContext:
          privileged: true    # VIOLATION: running as privileged
          runAsUser: 0        # VIOLATION: running as root
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f non-compliant-app.yaml
```

**Expected result:** Kubernetes emits a PSS violation warning. The deployment object is created but its pods are blocked from starting because `privileged: true` violates the Baseline standard.

**Why `privileged: true` is dangerous:** A privileged container has nearly unrestricted access to the host kernel — it can mount host filesystems, modify network interfaces, load kernel modules, and escape the container entirely.

### Step 4: Deploy a compliant app

```yaml
# compliant-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compliant-app
  namespace: secure-microservices
spec:
  replicas: 2
  selector:
    matchLabels:
      app: compliant-app
  template:
    metadata:
      labels:
        app: compliant-app
    spec:
      securityContext:
        runAsNonRoot: true       # Pod must not run as root
        runAsUser: 1000          # Specific non-root UID
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: app
        image: nginx:alpine
        securityContext:
          allowPrivilegeEscalation: false   # Cannot gain more privileges
          readOnlyRootFilesystem: true       # Root FS is read-only
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL                           # Drop all Linux capabilities
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: var-cache-nginx
          mountPath: /var/cache/nginx
        - name: var-run
          mountPath: /var/run
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: var-cache-nginx
        emptyDir: {}
      - name: var-run
        emptyDir: {}
```

```bash
kubectl apply -f compliant-app.yaml
kubectl get pods -n secure-microservices
```

### What each security setting does

| Setting | Value | Explanation |
|---|---|---|
| `runAsNonRoot` | `true` | Prevents the container from starting if the image's user is root |
| `runAsUser` | `1000` | Forces a specific non-root UID |
| `allowPrivilegeEscalation` | `false` | Prevents `setuid` binaries from escalating privileges |
| `readOnlyRootFilesystem` | `true` | Any write to the container FS fails — malware cannot persist |
| `capabilities: drop: ALL` | — | Removes all Linux capabilities (raw sockets, ptrace, etc.) |

### Step 5: Verify compliance

```bash
# Confirm pod runs as uid 1000
kubectl exec -n secure-microservices deployment/compliant-app -- id
# Output: uid=1000 gid=1000

# Check security context in pod spec
kubectl get pod -n secure-microservices -l app=compliant-app -o yaml | grep -A 10 securityContext

# Check for any violations in events
kubectl get events -n secure-microservices --sort-by='.lastTimestamp'
```

---

## Task 2 — Minimal Base Images

### Why image size matters for security

Every package installed in a container image is a potential attack vector. A standard `python:3.11` image ships with a full Debian/Ubuntu userland — compilers, package managers, shell utilities, networking tools — none of which your application needs at runtime. If an attacker exploits your app, they inherit all of those tools.

**The principle:** ship only what you need to run, nothing more.

### Application code

```python
# app.py — simple Flask microservice
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        'message': 'Hello from secure microservice!',
        'hostname': os.environ.get('HOSTNAME', 'unknown'),
        'version': '1.0'
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

```text
# requirements.txt
Flask==2.3.3
Werkzeug==2.3.7
```

### Critical Minikube step: point Docker at Minikube's daemon

```bash
eval $(minikube docker-env)
```

Without this, images you build on the host are invisible to Minikube's Kubernetes. This command re-exports `DOCKER_HOST` and related variables so `docker build` writes directly into Minikube's image store.

### Standard image (baseline for comparison)

```dockerfile
# Dockerfile.standard
FROM python:3.11
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8080
CMD ["python", "app.py"]
```

```bash
docker build -f Dockerfile.standard -t microservice-app:standard .
```

**Approximate size:** ~1 GB — ships with full Debian, gcc, make, apt, and hundreds of packages.

### Alpine-based minimal image

```dockerfile
# Dockerfile.alpine
FROM python:3.11-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser && \
    chown -R appuser:appgroup /app
USER appuser
EXPOSE 8080
CMD ["python", "app.py"]
```

```bash
docker build -f Dockerfile.alpine -t microservice-app:alpine .
```

**Approximate size:** ~60–80 MB — Alpine Linux is a minimal musl-based distro with no unnecessary tooling.

### Build command syntax (common mistake)

```bash
# WRONG — -t sets the tag name, does not select the Dockerfile
docker build -t Dockerfile.alpine .

# CORRECT — -f selects the file, -t sets the image name:tag
docker build -f Dockerfile.alpine -t microservice-app:alpine .
```

### Compare sizes

```bash
docker images | grep microservice-app
```

| Image | Approx Size | Packages |
|---|---|---|
| `microservice-app:standard` | ~1 GB | Full Debian + gcc + apt |
| `microservice-app:alpine` | ~70 MB | Minimal Alpine only |

The Alpine image is roughly **10–15x smaller**, meaning a proportionally smaller attack surface.

### Deploy minimal app to Kubernetes

```yaml
# minimal-app-deployment.yaml (key sections)
containers:
- name: app
  image: microservice-app:alpine
  imagePullPolicy: Never          # Use locally built image in Minikube
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
      - ALL
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "128Mi"
      cpu: "100m"
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /health
      port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
```

```bash
kubectl apply -f minimal-app-deployment.yaml
kubectl wait --for=condition=ready pod -l app=minimal-app -n secure-microservices --timeout=60s
```

**Why `imagePullPolicy: Never`?** In Minikube, Kubernetes and your host shell share a Docker daemon only when you run `eval $(minikube docker-env)`. If you forget this, or if `imagePullPolicy` is `Always` or `IfNotPresent`, Kubernetes tries to pull from Docker Hub instead, which fails because the image only exists locally.

### Test the application

```bash
kubectl port-forward -n secure-microservices service/minimal-app-service 8080:80 &
sleep 3
curl http://localhost:8080/
curl http://localhost:8080/health
pkill -f "kubectl port-forward"
```

---

## Task 3 — gVisor Application Sandboxing

### What is gVisor?

gVisor is a **user-space kernel** developed by Google. When a container runs under gVisor, its syscalls do not reach the host Linux kernel directly. Instead they are intercepted by gVisor's `runsc` component, which implements a subset of the Linux kernel API in user space.

```
Normal container:          gVisor container:
App → syscall → Host kernel   App → syscall → gVisor (runsc) → Host kernel
```

This means a container escape exploit that abuses a host kernel vulnerability cannot work — the container never touches the real kernel.

### Minikube setup for gVisor

gVisor requires the `containerd` container runtime, not Docker's default runtime.

```bash
# Start Minikube with containerd
minikube start \
  --driver=docker \
  --container-runtime=containerd \
  --cpus=2 \
  --memory=4096

# Enable the gVisor addon (installs runsc on the Minikube node)
minikube addons enable gvisor

# Verify the RuntimeClass was created
kubectl get runtimeclass
```

### RuntimeClass resource

Kubernetes uses a `RuntimeClass` object to map a name to a container runtime handler on the node.

```yaml
# gvisor-runtime-class.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc        # maps to the runsc binary installed by the addon
```

```bash
kubectl apply -f gvisor-runtime-class.yaml
kubectl get runtimeclass gvisor -o yaml
```

### Deploy the sandboxed application

The only change from `minimal-app-deployment.yaml` is adding `runtimeClassName: gvisor` to the pod spec:

```yaml
# sandboxed-app-deployment.yaml (key difference)
spec:
  runtimeClassName: gvisor      # This line activates gVisor for every pod in this deployment
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: microservice-app:alpine
    imagePullPolicy: Never
    resources:
      requests:
        memory: "128Mi"    # gVisor needs more memory than a regular container
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
    livenessProbe:
      initialDelaySeconds: 45  # gVisor starts slower than a regular container
```

```bash
kubectl apply -f sandboxed-app-deployment.yaml
kubectl get pods -n secure-microservices -l app=sandboxed-app -w
```

**Why more memory and longer probe delays?** gVisor runs an entire user-space kernel alongside your application. This overhead means pods use more memory at startup and take longer to become ready.

### Proof that gVisor is working

```bash
# Check /proc/version inside gVisor pod
kubectl exec -n secure-microservices deployment/sandboxed-app -- cat /proc/version

# Check /proc/version inside regular pod
kubectl exec -n secure-microservices deployment/minimal-app -- cat /proc/version
```

**Actual output from this lab:**

```
=== gVisor container ===
Linux version 4.4.0 #1 SMP Sun Jan 10 15:06:54 PST 2016

=== Regular container ===
Linux version 6.14.0-1018-aws (buildd@lcy02-amd64-107) ...
```

This is definitive proof. The gVisor pod reports a fake kernel version (`4.4.0`, gVisor's simulated kernel) while the regular pod reports the real AWS host kernel (`6.14.0-1018-aws`). The sandboxed container cannot see or reach the real host kernel.

### Port-forward limitation with gVisor

`kubectl port-forward` does not work with gVisor pods. This is a known limitation — gVisor intercepts network syscalls differently, breaking the port-forward tunnel. To test gVisor pods over HTTP, use a temporary curl pod inside the cluster:

```bash
SANDBOXED_IP=$(kubectl get pods -n secure-microservices -l app=sandboxed-app \
  -o jsonpath='{.items[0].status.podIP}')

kubectl run curl-test --image=curlimages/curl --restart=Never --rm -it \
  -n secure-microservices \
  -- curl http://$SANDBOXED_IP:8080/health
```

### Performance comparison

```bash
# Regular container
kubectl exec -n secure-microservices deployment/minimal-app -- python3 -c "
import time; start = time.time()
for i in range(10000): pass
print('Time: {:.4f}s'.format(time.time() - start))
"

# gVisor sandboxed container
kubectl exec -n secure-microservices deployment/sandboxed-app -- python3 -c "
import time; start = time.time()
for i in range(10000): pass
print('Time: {:.4f}s'.format(time.time() - start))
"
```

gVisor introduces a small performance overhead for syscall-heavy workloads. Pure compute (loops, math) is nearly identical. The overhead is most noticeable in I/O and networking operations, which is the expected tradeoff for the security guarantee.

---

## Task 4 — Security Analysis and Report

### Network policy

A NetworkPolicy restricts which pods can talk to which other pods, and what external traffic is allowed. Without a NetworkPolicy, all pods in a namespace can freely communicate.

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secure-microservices-policy
  namespace: secure-microservices
spec:
  podSelector: {}       # Applies to ALL pods in the namespace
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: secure-microservices
    ports:
    - protocol: TCP
      port: 8080        # Only allow inbound on port 8080 from within namespace
  egress:
  - ports:
    - protocol: TCP
      port: 53          # Allow DNS lookups
    - protocol: UDP
      port: 53
  - ports:
    - protocol: TCP
      port: 443         # Allow HTTPS outbound only
```

```bash
kubectl apply -f network-policy.yaml
kubectl describe networkpolicy secure-microservices-policy -n secure-microservices
```

**What this policy enforces:**
- Pods can only receive traffic from within the same namespace on port 8080
- Pods can only initiate outbound DNS (port 53) and HTTPS (port 443) connections
- All other inbound and outbound traffic is blocked

### Security report generation

```bash
# generate-security-report.sh
#!/bin/bash

echo "=== MICROSERVICE SECURITY REPORT ==="
echo "Generated on: $(date)"

echo "1. NAMESPACE SECURITY CONFIGURATION:"
kubectl get namespace secure-microservices --show-labels

echo "2. POD SECURITY STANDARDS:"
kubectl get pods -n secure-microservices \
  -o custom-columns="NAME:.metadata.name,RUNTIME:.spec.runtimeClassName,USER:.spec.securityContext.runAsUser,NON-ROOT:.spec.securityContext.runAsNonRoot"

echo "3. IMAGE SIZES:"
docker images | grep microservice-app

echo "4. SECURITY CONTEXTS:"
kubectl get pods -n secure-microservices \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].securityContext}{"\n"}{end}'

echo "5. NETWORK POLICIES:"
kubectl get networkpolicy -n secure-microservices
```

```bash
chmod +x generate-security-report.sh
./generate-security-report.sh | tee security-report.txt
```

---

## Key Concepts Summary

### Three layers of defense

```
Layer 1: Pod Security Standards
  └─ Controls WHAT a pod is allowed to do (no root, no privilege escalation)

Layer 2: Minimal Base Images
  └─ Controls WHAT tools exist inside the container (nothing unnecessary)

Layer 3: gVisor Sandboxing
  └─ Controls WHAT the container can see of the host (fake kernel, no direct syscalls)
```

Each layer independently reduces risk. Together they make it very difficult for an attacker to exploit a vulnerability in the application, escalate privileges within the container, or escape to the host.

### PSS violation reference

| Forbidden setting | Why it violates Baseline |
|---|---|
| `privileged: true` | Full host access |
| `runAsUser: 0` | Root user inside container |
| `hostPID: true` | Can see/kill host processes |
| `hostNetwork: true` | Bypasses network isolation |
| `capabilities: add: [NET_RAW]` | Raw socket access |

### Image size security impact

Fewer packages = fewer CVEs. A 70 MB Alpine image has an order of magnitude fewer installed packages than a 1 GB Debian image, which directly translates to fewer known vulnerabilities that could be exploited if an attacker gains code execution inside the container.

### gVisor tradeoffs

| Benefit | Tradeoff |
|---|---|
| Host kernel invisible to container | Slight startup latency |
| Syscall exploits blocked | Higher memory usage per pod |
| Container escape near-impossible | `kubectl port-forward` does not work |
| Works with existing container images | Not all syscalls are implemented |

---

## Troubleshooting Notes

### Docker build fails with `404 page not found`

**Cause:** Docker is using the `buildx` remote driver which can't reach its daemon.

**Fix:**
```bash
export DOCKER_BUILDKIT=0
docker build -f Dockerfile.alpine -t microservice-app:alpine .
```

### `ErrImageNeverPull` on pod startup

**Cause:** `imagePullPolicy: Never` but the image isn't in Minikube's Docker store.

**Fix:** Run `eval $(minikube docker-env)` before building, then rebuild the image.

### gVisor pod port-forward fails

**Cause:** Known gVisor limitation — network syscall interception breaks the port-forward mechanism.

**Fix:** Test using a temporary pod inside the cluster:
```bash
kubectl run curl-test --image=curlimages/curl --restart=Never --rm -it \
  -n secure-microservices -- curl http://<POD_IP>:8080/health
```

### Pods pending after Minikube restart

**Cause:** Images are lost when Minikube restarts.

**Fix:**
```bash
eval $(minikube docker-env)
cd ~/lab/minimizing-micorservice/microservice-app
docker build -f Dockerfile.alpine -t microservice-app:alpine .
```

---

## File Structure

| File | Purpose |
|---|---|
| `compliant-app.yaml` | Nginx deployment meeting Baseline PSS |
| `non-compliant-app.yaml` | Privileged deployment used to demonstrate policy blocking |
| `microservice-app/app.py` | Flask application with `/` and `/health` endpoints |
| `microservice-app/requirements.txt` | Flask==2.3.3, Werkzeug==2.3.7 |
| `microservice-app/Dockerfile.standard` | Full `python:3.11` image (~1 GB) |
| `microservice-app/Dockerfile.alpine` | Minimal `python:3.11-alpine` image (~70 MB) |
| `microservice-app/minimal-app-deployment.yaml` | Alpine image deployed with full security contexts |
| `microservice-app/sandboxed-app-deployment.yaml` | Same app with `runtimeClassName: gvisor` |
| `microservice-app/gvisor-runtime-class.yaml` | Maps `gvisor` name to `runsc` handler |
| `microservice-app/network-policy.yaml` | Restricts ingress/egress for all pods in namespace |
| `microservice-app/generate-security-report.sh` | Collects and prints security posture summary |
| `microservice-app/security-report.txt` | Output of the security report script |
| `performance-test.sh` | Compares execution time between regular and gVisor pods |
