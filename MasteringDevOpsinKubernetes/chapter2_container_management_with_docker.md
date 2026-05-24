# Chapter 2 — Container Management with Docker

> *Mastering DevOps in Kubernetes*
> Images · Containers · Volumes · Networking · Compose · Registries · CRI

---

## 1. Introduction & Learning Objectives

If Kubernetes is the operating system of the cloud-native world, Docker is the packaging format that made it possible. Every workload you deploy to Kubernetes — every Pod, every Init Container, every sidecar — begins its life as a container image. Understanding how those images are built, optimized, stored, and executed is not optional knowledge for a Kubernetes practitioner. It is the foundation on which everything else rests.

This chapter is a deep, practitioner-focused exploration of Docker and the container ecosystem. We begin with the internals of how Linux containers actually work, build up through Dockerfile authoring and multi-stage build patterns, cover image optimization strategies that directly impact cluster pull latency and security posture, and finish by connecting Docker's concepts to Kubernetes through the Container Runtime Interface (CRI).

By the time you finish this chapter, you will not only be able to write production-grade Dockerfiles — you will understand why they are written the way they are.

> **Learning Objectives**
> - Explain how Linux namespaces and cgroups provide container isolation without a hypervisor.
> - Build, tag, and push container images using Dockerfile best practices.
> - Apply multi-stage build patterns to produce minimal, secure production images.
> - Optimize images for size, layer caching, and security scanning compliance.
> - Use Docker volumes and bind mounts for persistent and shared data.
> - Configure Docker networking for single-host and multi-container communication.
> - Orchestrate multi-service local environments using Docker Compose.
> - Push and pull images from Docker Hub, ECR, GCR, and ACR.
> - Explain how the Container Runtime Interface (CRI) connects Docker concepts to Kubernetes.

---

## 2. Core Concepts

### 2.1 How Linux Containers Actually Work

A common misconception among engineers new to containers is that they are a lightweight version of virtual machines. They are not. Containers are not virtualization — they are isolation. They are regular Linux processes running on the host kernel, constrained and isolated by two Linux kernel features: **namespaces** and **cgroups**.

#### Linux Namespaces

A namespace wraps a global system resource in an abstraction that makes it appear to the processes within the namespace that they have their own isolated instance of that resource. Docker uses six namespaces to create the illusion of an isolated environment:

| Namespace | Isolates | What the Container Sees |
|---|---|---|
| `pid` | Process IDs | Its own PID 1; cannot see host processes |
| `net` | Network interfaces | Its own `eth0`, routing table, and port space |
| `mnt` | Filesystem mount points | Its own root filesystem (the image layers) |
| `uts` | Hostname and domain name | Its own hostname (container ID by default) |
| `ipc` | IPC resources (semaphores, shared memory) | Isolated IPC namespace |
| `user` | User and group IDs | Can map container root to unprivileged host UID |

#### Control Groups (cgroups)

While namespaces provide isolation, cgroups provide **resource enforcement**. They are the mechanism by which Docker (and ultimately Kubernetes) limits how much CPU, memory, network I/O, and disk I/O a container can consume:

```bash
# Inspect the cgroup configuration of a running container
docker run -d --name demo --memory=128m --cpus=0.5 nginx:alpine

# The kernel exposes cgroup limits under:
# /sys/fs/cgroup/memory/docker/<container-id>/memory.limit_in_bytes
# /sys/fs/cgroup/cpu/docker/<container-id>/cpu.cfs_quota_us

docker inspect demo --format '{{.HostConfig.Memory}}'
# 134217728  (128MB in bytes)
```

This maps directly to Kubernetes resource limits. When you write `limits.memory: 128Mi` in a Pod spec, Kubernetes is setting the same underlying cgroup knobs that Docker sets when you pass `--memory=128m`.

#### Union Filesystems and Image Layers

Container images are composed of read-only layers stacked on top of each other using a **union filesystem** (OverlayFS on modern Linux systems). Each instruction in a Dockerfile that modifies the filesystem creates a new layer. When a container runs, a thin writable layer is added on top:

```
┌─────────────────────────────────┐  <- Writable container layer (ephemeral)
├─────────────────────────────────┤  <- RUN npm install (Layer 4)
├─────────────────────────────────┤  <- COPY package.json (Layer 3)
├─────────────────────────────────┤  <- RUN apt-get install (Layer 2)
└─────────────────────────────────┘  <- FROM node:20-alpine (Layer 1, base image)
```

The critical insight: **layers are content-addressed and shared across images**. If ten containers all use `node:20-alpine` as their base, the host only stores that base layer once. This is why image layer caching is so important — both for build speed and for storage efficiency in a Kubernetes node's image cache.

---

### 2.2 Docker Architecture

Docker uses a client-server architecture with three main components:

```
┌──────────────────────────────────────────────────────────────────┐
│  Docker Host                                                      │
│                                                                   │
│  ┌─────────────┐    REST API    ┌──────────────────────────────┐ │
│  │ Docker CLI  │ <-----------> │     dockerd (daemon)          │ │
│  │ (client)    │               │                               │ │
│  └─────────────┘               │  ┌────────────┐  ┌────────┐  │ │
│                                │  │  containerd │  │ Images │  │ │
│  ┌─────────────┐               │  │  (runtime)  │  │ Cache  │  │ │
│  │ Docker      │               │  └──────┬─────┘  └────────┘  │ │
│  │ Compose     │               │         │                     │ │
│  └─────────────┘               │  ┌──────▼─────┐              │ │
│                                │  │  runc       │              │ │
│                                │  │ (OCI runtime)│             │ │
│                                │  └──────┬─────┘              │ │
│                                │         │                     │ │
│                                │  ┌──────▼──────────────────┐ │ │
│                                │  │  Linux Kernel            │ │ │
│                                │  │  (namespaces + cgroups)  │ │ │
│                                │  └─────────────────────────┘ │ │
│                                └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
         │
         │  pull/push
         ▼
┌──────────────────┐
│ Container        │
│ Registry         │
│ (Hub/ECR/GCR/ACR)│
└──────────────────┘
```

| Component | Role |
|---|---|
| `docker` CLI | Client that sends commands to the daemon via REST API |
| `dockerd` | Long-running daemon managing images, containers, networks, volumes |
| `containerd` | High-level container runtime; manages container lifecycle |
| `runc` | Low-level OCI-compliant runtime; makes the `clone()` syscalls |
| Container Registry | Remote image store; Docker Hub, ECR, GCR, ACR, Harbor |

> **Important for Kubernetes:** As of Kubernetes 1.24, `dockershim` was removed. Kubernetes no longer uses `dockerd` directly. It communicates with container runtimes via the **Container Runtime Interface (CRI)** — covered in Section 2.9.

---

### 2.3 Images vs. Containers

One of the most important conceptual distinctions in the container world:

| | Image | Container |
|---|---|---|
| **What it is** | Read-only, immutable template | Running (or stopped) instance of an image |
| **Analogy** | Class definition in OOP | Object instance |
| **Storage** | Stored as content-addressed layers on disk | Adds a thin writable layer on top of image layers |
| **Lifecycle** | Created by `docker build`; exists until deleted | Created by `docker run`; ephemeral by design |
| **State** | Stateless — never changes after build | Stateful during runtime; state lost on removal |
| **Portability** | Fully portable — push to registry, pull anywhere | Tied to the host it runs on |

The implications for Kubernetes: a Pod spec references an image. Kubernetes pulls that image to the node and creates a container from it. If the container crashes, Kubernetes creates a new container from the same image — clean slate. Any state that must survive a container restart must be stored outside the container (PersistentVolume, external database, object storage).

---

### 2.4 Dockerfile Deep Dive

A Dockerfile is a text file containing ordered instructions for building a container image. Each instruction that modifies the filesystem creates a new layer. Understanding the performance and security implications of each instruction is essential for writing production-quality Dockerfiles.

#### Dockerfile Instruction Reference

```dockerfile
# FROM — base image (always first; use specific tags, never 'latest')
FROM node:20.11-alpine3.19

# LABEL — image metadata (OCI annotations; useful for automation)
LABEL maintainer="platform-team@company.com" \
      version="1.0.0" \
      description="Demo Node.js API"

# ARG — build-time variables (NOT available at runtime; safe for build secrets)
ARG NODE_ENV=production
ARG BUILD_DATE

# ENV — runtime environment variables (persisted in image; visible to container)
ENV NODE_ENV=${NODE_ENV} \
    PORT=3000 \
    NPM_CONFIG_LOGLEVEL=error

# WORKDIR — sets working directory; creates it if it does not exist
WORKDIR /app

# COPY — preferred over ADD for local files (ADD has URL fetching side effects)
COPY package*.json ./

# RUN — executes a command during build; creates a layer
# Best practice: combine RUN commands with && to minimize layers
RUN npm ci --only=production \
    && npm cache clean --force \
    && rm -rf /tmp/*

# COPY remaining source after installing dependencies (layer cache optimization)
COPY src/ ./src/

# USER — run as non-root (critical for security; required by many K8s policies)
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup && \
    chown -R appuser:appgroup /app
USER appuser

# EXPOSE — documents the port (does not actually publish; informational only)
EXPOSE 3000

# HEALTHCHECK — Docker-level health check (Kubernetes uses probes instead)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# CMD vs ENTRYPOINT:
# ENTRYPOINT — the executable that always runs; cannot be overridden by docker run args
# CMD — default arguments to ENTRYPOINT (or the command if no ENTRYPOINT is set)
ENTRYPOINT ["node"]
CMD ["src/server.js"]
```

#### Layer Caching Strategy

Docker rebuilds a layer and all subsequent layers when the layer's input changes. Ordering your instructions to maximize cache reuse is one of the highest-leverage optimizations in Dockerfile authoring:

```dockerfile
# BAD: Copying all source first means ANY code change invalidates the npm install layer
FROM node:20-alpine
WORKDIR /app
COPY . .                        # Cache invalidated on every code change
RUN npm ci                      # Re-runs on every code change — slow

# GOOD: Separate dependency installation from source copying
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./           # Only invalidated when package.json changes
RUN npm ci                      # Cached until dependencies change — fast
COPY src/ ./src/                # Invalidated on code change, but npm ci is cached
```

---

### 2.5 Multi-Stage Builds

Multi-stage builds are the single most impactful Dockerfile technique for producing lean, secure production images. They allow you to use a full build environment (with compilers, build tools, test frameworks) in early stages, then copy only the compiled artifacts into a minimal final image.

#### Why Multi-Stage Builds Matter

| | Without Multi-Stage | With Multi-Stage |
|---|---|---|
| Build tools in production image | Yes | No |
| Source code in production image | Yes | No |
| Typical Node.js image size | 1.2 GB | 85 MB |
| Typical Go binary image size | 1.1 GB | 12 MB |
| Attack surface | Large | Minimal |
| CVE exposure | High | Low |

#### Go Application — Minimal Binary

```dockerfile
# ─── Stage 1: Build ───────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# Cache module downloads separately from source compilation
COPY go.mod go.sum ./
RUN go mod download

# Copy source and compile
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=$(git describe --tags --always)" \
    -o /bin/server \
    ./cmd/server

# ─── Stage 2: Test (optional but recommended) ────────────────────
FROM builder AS tester
RUN go test -v -race -coverprofile=coverage.txt ./...

# ─── Stage 3: Production ─────────────────────────────────────────
# 'scratch' is a completely empty image — no shell, no package manager
# Only the statically compiled binary and required system files
FROM scratch AS production

# Copy CA certificates for HTTPS calls
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
# Copy the binary
COPY --from=builder /bin/server /bin/server

# Non-root user in scratch (must use numeric UID — no passwd file)
USER 65534:65534

EXPOSE 8080
ENTRYPOINT ["/bin/server"]
```

#### Node.js Application — Production-Ready

```dockerfile
# ─── Stage 1: Dependencies ────────────────────────────────────────
FROM node:20.11-alpine3.19 AS deps
WORKDIR /app
COPY package*.json ./
# ci is reproducible (uses package-lock.json exactly); only production deps
RUN npm ci --only=production && npm cache clean --force

# ─── Stage 2: Build (TypeScript compile, asset bundling, etc.) ───
FROM node:20.11-alpine3.19 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci                          # Install ALL deps including devDependencies
COPY tsconfig.json .
COPY src/ ./src/
RUN npm run build                   # Compile TypeScript → dist/

# ─── Stage 3: Test ───────────────────────────────────────────────
FROM builder AS tester
COPY tests/ ./tests/
RUN npm test && npm run lint

# ─── Stage 4: Production ─────────────────────────────────────────
FROM node:20.11-alpine3.19 AS production

# Security hardening
RUN apk add --no-cache dumb-init && \
    addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

# Copy only what production needs
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs package.json ./

USER nodejs
EXPOSE 3000

# dumb-init as PID 1: handles SIGTERM properly (Factor IX)
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

#### Java / Spring Boot Application

```dockerfile
# ─── Stage 1: Build with Maven ───────────────────────────────────
FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build

# Cache Maven dependencies — only re-downloaded when pom.xml changes
COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src/ ./src/
RUN mvn clean package -DskipTests -B

# ─── Stage 2: Extract Spring Boot layers ─────────────────────────
FROM eclipse-temurin:21-jre-alpine AS extractor
WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar
# Spring Boot layertools extracts jar into layers for optimal Docker caching
RUN java -Djarmode=layertools -jar app.jar extract

# ─── Stage 3: Production ─────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS production

RUN addgroup -g 1001 -S spring && adduser -u 1001 -S spring -G spring
WORKDIR /app

# Copy layers in order of change frequency (least → most frequent)
COPY --from=extractor --chown=spring:spring /app/dependencies/ ./
COPY --from=extractor --chown=spring:spring /app/spring-boot-loader/ ./
COPY --from=extractor --chown=spring:spring /app/snapshot-dependencies/ ./
COPY --from=extractor --chown=spring:spring /app/application/ ./

USER spring
EXPOSE 8080

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "org.springframework.boot.loader.JarLauncher"]
```

> **Production Tip — JVM Container Awareness**
> Before JDK 10, the JVM ignored cgroup memory limits and used the host's total RAM to size its heap. A 512Mi container on a 64GB host would default to a 16GB heap and immediately OOM-kill. Always use `-XX:+UseContainerSupport` (default in JDK 11+) and `-XX:MaxRAMPercentage=75.0` to respect the container's memory limit.

---

### 2.6 Image Optimization

Beyond multi-stage builds, several additional techniques reduce image size, improve security posture, and reduce Kubernetes node pull times.

#### Choose the Right Base Image

| Base Image | Size | Use Case |
|---|---|---|
| `ubuntu:24.04` | ~78 MB | General-purpose; full apt ecosystem |
| `debian:bookworm-slim` | ~75 MB | Smaller Debian; good for most compiled apps |
| `alpine:3.19` | ~7 MB | Minimal; musl libc (watch for glibc incompatibilities) |
| `distroless/static` | ~2 MB | No shell, no package manager; compiled binaries only |
| `distroless/base` | ~20 MB | glibc + CA certs; good for Go/Rust binaries |
| `scratch` | 0 MB | Completely empty; statically linked binaries only |

#### .dockerignore — Your First Line of Defence

A missing `.dockerignore` is one of the most common Dockerfile mistakes. Without it, `COPY . .` sends your entire build context — including `.git`, `node_modules`, test fixtures, and local secrets — to the Docker daemon on every build.

```
# .dockerignore
# Version control
.git
.gitignore

# Dependencies (rebuilt inside Docker)
node_modules/
vendor/
target/

# Test artifacts
coverage/
*.test
tests/
__tests__/
spec/

# IDE and OS artifacts
.idea/
.vscode/
.DS_Store
*.swp

# Local environment files (NEVER send to build context)
.env
.env.local
.env.*.local
*.pem
*.key

# Documentation (not needed in production image)
docs/
*.md
README*

# CI/CD configs
.github/
.gitlab-ci.yml
Jenkinsfile
```

#### Image Size Reduction Checklist

```dockerfile
# 1. Remove package manager caches in the same RUN layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Use --no-install-recommends to skip suggested packages
# (can reduce install size by 40-60%)

# 3. Remove build-only tools after use
RUN apk add --no-cache --virtual .build-deps \
    gcc musl-dev \
    && pip install --no-cache-dir -r requirements.txt \
    && apk del .build-deps          # Removes gcc, musl-dev but keeps pip output

# 4. Squash intermediate layers (use sparingly — breaks layer sharing)
# Build with: docker build --squash .

# 5. Use COPY --link (BuildKit) for better layer deduplication
COPY --link --chown=app:app src/ ./src/
```

#### Scanning Images for CVEs

Image scanning should be a mandatory gate in your CI pipeline before any image is pushed to production registries:

```bash
# Trivy — open source, fast, comprehensive
trivy image myapp:1.0.0

# Example output:
# myapp:1.0.0 (alpine 3.18.4)
# ===========================
# Total: 3 (CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 0)
#
# ┌──────────────┬────────────┬──────────┬──────────────────────┐
# │  Library     │    CVE     │ Severity │ Installed → Fixed    │
# ├──────────────┼────────────┼──────────┼──────────────────────┤
# │ openssl      │ CVE-2024-X │ HIGH     │ 3.1.3 → 3.1.4        │
# └──────────────┴────────────┴──────────┴──────────────────────┘

# Grype — Anchore's scanner; excellent for compliance workflows
grype myapp:1.0.0 --fail-on high

# Docker Scout (built into Docker Desktop and Docker Hub)
docker scout cves myapp:1.0.0
docker scout recommendations myapp:1.0.0   # Suggests better base images
```

---

### 2.7 Docker Volumes and Storage

Containers are ephemeral. Any data written to the container's writable layer is lost when the container is removed. Docker provides three mechanisms for persisting or sharing data:

| Mechanism | Managed By | Use Case |
|---|---|---|
| Named Volume | Docker daemon | Persistent data; survives container removal; portable |
| Bind Mount | Host filesystem | Local development; sharing host files with container |
| tmpfs Mount | Host memory | Sensitive temporary data; never written to disk |

#### Named Volumes

```bash
# Create a named volume
docker volume create pgdata

# Mount it into a container
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16-alpine

# Inspect the volume
docker volume inspect pgdata
# [{"Name": "pgdata", "Mountpoint": "/var/lib/docker/volumes/pgdata/_data", ...}]

# Volume persists after container removal
docker rm -f postgres
docker volume ls                    # pgdata still exists
```

#### Bind Mounts for Local Development

```bash
# Mount the current directory into the container (hot-reload workflows)
docker run -it \
  --name dev-server \
  -v "$(pwd)/src:/app/src:ro" \    # :ro = read-only (prevent container writes)
  -v "$(pwd)/config:/app/config" \
  -p 3000:3000 \
  myapp:dev

# In Dockerfile, use a named volume to prevent node_modules from being overwritten
# by the bind mount (a classic gotcha in Node.js development):
# VOLUME ["/app/node_modules"]
```

#### Volume Drivers for Cloud Storage

```bash
# AWS EFS (NFS-compatible) via the efs driver
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=<efs-endpoint>,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
  --opt device=:/ \
  efs-volume
```

> **Kubernetes Mapping:** Docker named volumes map to Kubernetes PersistentVolumeClaims (PVCs). Bind mounts map to `hostPath` volumes (use with caution in production). The concepts are identical; only the API surface differs.

---

### 2.8 Docker Networking

Docker networking is one of the most underappreciated topics among engineers who later struggle with Kubernetes networking. The two systems share the same underlying model — every container gets an IP, containers communicate over virtual networks, and external traffic enters via port mapping or ingress.

#### Docker Network Drivers

| Driver | Scope | Use Case |
|---|---|---|
| `bridge` (default) | Single host | Isolated network for containers on one Docker host |
| `host` | Single host | Container shares host network stack; no isolation |
| `overlay` | Multi-host | Docker Swarm; containers across multiple hosts |
| `macvlan` | Single host | Container needs a MAC address on the physical LAN |
| `none` | Single host | Complete network isolation; no interfaces |

#### Bridge Networks in Detail

```bash
# The default bridge network (docker0) — all containers can talk; no DNS by name
docker run -d --name app1 nginx:alpine
docker run -d --name app2 nginx:alpine
docker exec app2 ping app1          # FAILS — default bridge has no DNS

# Create a user-defined bridge network (has automatic DNS resolution by name)
docker network create --driver bridge app-network

docker run -d --name api     --network app-network myapi:latest
docker run -d --name db      --network app-network postgres:16-alpine
docker run -d --name cache   --network app-network redis:7-alpine

# api can now reach db as 'db:5432' and cache as 'cache:6379' — DNS by container name
docker exec api ping db             # SUCCESS
docker exec api ping cache          # SUCCESS

# Inspect the network
docker network inspect app-network
```

#### Port Mapping

```bash
# Map host port 8080 to container port 3000
docker run -d -p 8080:3000 myapp:latest

# Bind to a specific host interface (security best practice in production)
docker run -d -p 127.0.0.1:8080:3000 myapp:latest   # localhost only

# Random host port (useful in CI to avoid port conflicts)
docker run -d -p 3000 myapp:latest
docker port <container-id>          # Shows the assigned host port

# Multiple port mappings
docker run -d \
  -p 8080:3000 \
  -p 9090:9090 \    # Prometheus metrics endpoint
  myapp:latest
```

#### Network Namespace Sharing (Kubernetes Pods)

In Kubernetes, all containers within a Pod share a single network namespace. This is achieved via a `pause` container (also called the "infra container") that holds the network namespace open for the lifetime of the Pod. This is why containers within a Pod communicate over `localhost` — they share the same network interfaces.

```bash
# Simulate a Kubernetes Pod's network sharing with Docker
# Start the pause container (holds the network namespace)
docker run -d --name pause gcr.io/google-containers/pause:3.9

# Join the pause container's network namespace
docker run -d --name app   --network container:pause myapp:latest
docker run -d --name sidecar --network container:pause envoy:v1.29

# Now 'app' and 'sidecar' share network interfaces
# 'sidecar' can reach 'app' via localhost:3000
```

---

### 2.9 Docker Compose

Docker Compose is a tool for defining and running multi-container applications from a single YAML file. It is the standard tool for local development environments that mirror production microservices architectures.

#### Production-Grade Docker Compose Configuration

```yaml
# docker-compose.yml
# Version is optional for Compose V2 (docker compose, not docker-compose)
services:

  # ── API Service ──────────────────────────────────────────────────
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: production           # Use the 'production' multi-stage target
      args:
        - NODE_ENV=production
    image: myapp/api:${TAG:-latest}
    container_name: api
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD}@db:5432/appdb
      - REDIS_URL=redis://cache:6379
    env_file:
      - .env.local                 # Local overrides; gitignored
    depends_on:
      db:
        condition: service_healthy  # Wait for DB health check before starting
      cache:
        condition: service_started
    networks:
      - backend
      - frontend
    volumes:
      - ./logs:/app/logs           # Persist logs outside container
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M

  # ── Database ─────────────────────────────────────────────────────
  db:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD:?DB_PASSWORD must be set}
    volumes:
      - pgdata:/var/lib/postgresql/data    # Named volume for persistence
      - ./db/init:/docker-entrypoint-initdb.d:ro  # Init SQL scripts
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  # ── Redis Cache ──────────────────────────────────────────────────
  cache:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redisdata:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  # ── Prometheus (observability) ───────────────────────────────────
  prometheus:
    image: prom/prometheus:v2.51.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./observability/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - promdata:/prometheus
    networks:
      - backend
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'

  # ── Nginx Reverse Proxy ──────────────────────────────────────────
  nginx:
    image: nginx:1.25-alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - api
    networks:
      - frontend

# ── Networks ──────────────────────────────────────────────────────
networks:
  backend:
    driver: bridge
    internal: true                 # No direct internet access from backend network
  frontend:
    driver: bridge

# ── Volumes ───────────────────────────────────────────────────────
volumes:
  pgdata:
    driver: local
  redisdata:
    driver: local
  promdata:
    driver: local
```

#### Docker Compose Profiles for Environment Variants

```yaml
# Use profiles to selectively start services
services:
  api:
    profiles: ["app", "full"]
    # ... service definition

  db:
    profiles: ["app", "full"]

  prometheus:
    profiles: ["monitoring", "full"]

  jaeger:
    image: jaegertracing/all-in-one:1.55
    profiles: ["monitoring", "full"]
    ports:
      - "16686:16686"   # Jaeger UI
      - "4317:4317"     # OTLP gRPC
```

```bash
# Start only the app services (api + db)
docker compose --profile app up -d

# Start everything including monitoring
docker compose --profile full up -d

# Scale a specific service
docker compose up -d --scale api=3
```

#### Essential Docker Compose Commands

```bash
# Start all services (detached)
docker compose up -d

# Start with a fresh build
docker compose up -d --build

# View service logs (follow mode)
docker compose logs -f api

# View logs from multiple services
docker compose logs -f api db

# Execute a command in a running service
docker compose exec api sh
docker compose exec db psql -U postgres appdb

# Scale a service (for stateless services)
docker compose up -d --scale api=3

# Show running services and their status
docker compose ps

# Stop without removing containers/volumes
docker compose stop

# Stop and remove containers, networks (preserves named volumes)
docker compose down

# Stop and remove EVERYTHING including volumes (careful — deletes data)
docker compose down --volumes --remove-orphans
```

---

### 2.10 Container Registries

A container registry is a content-addressable storage system for container images. Understanding registry architecture — authentication, image tagging strategies, and security features — is essential for operating Kubernetes in production.

#### Image Naming and Tagging

```
registry.hostname/namespace/repository:tag@digest

Examples:
docker.io/library/nginx:1.25-alpine                      # Docker Hub official image
docker.io/myorg/myapp:v1.4.2                             # Docker Hub personal/org
123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:v1.4.2  # AWS ECR
gcr.io/my-project/myapp:v1.4.2                          # Google Container Registry
myregistry.azurecr.io/myapp:v1.4.2                      # Azure Container Registry
ghcr.io/myorg/myapp:v1.4.2                              # GitHub Container Registry
```

#### Tagging Strategy for Kubernetes

```bash
# ── Semantic versioning (production standard) ─────────────────────
docker tag myapp:latest myapp:1.4.2
docker tag myapp:latest myapp:1.4           # Floating minor tag
docker tag myapp:latest myapp:1             # Floating major tag

# ── Git SHA tags (GitOps / Argo CD standard) ─────────────────────
GIT_SHA=$(git rev-parse --short HEAD)
docker build -t myapp:${GIT_SHA} .
docker push myapp:${GIT_SHA}
# In deployment.yaml: image: myapp:a3f9c12

# ── Immutable digest reference (most secure) ─────────────────────
docker pull myapp:1.4.2
docker inspect --format='{{index .RepoDigests 0}}' myapp:1.4.2
# myapp@sha256:3d88c5de8e7f44c6ccdd55e5e1dc90b1b90ad1a4ef3e19e8e56c1b9c3fa8d9ae
# In deployment.yaml: image: myapp@sha256:3d88c5de...
```

#### Docker Hub

```bash
# Authenticate
docker login

# Push an image
docker tag myapp:1.4.2 myorg/myapp:1.4.2
docker push myorg/myapp:1.4.2

# Multi-platform build and push (amd64 + arm64)
docker buildx create --use --name multiarch
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag myorg/myapp:1.4.2 \
  --push \
  .
```

#### AWS Elastic Container Registry (ECR)

```bash
# Authenticate (token valid for 12 hours)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

# Create repository (one-time)
aws ecr create-repository \
  --repository-name myapp \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Tag and push
docker tag myapp:1.4.2 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:1.4.2
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:1.4.2

# In Kubernetes, use IRSA (IAM Roles for Service Accounts) for ECR auth
# No stored credentials required — kubelet's ECR credential provider handles it
```

#### Google Container Registry / Artifact Registry

```bash
# Authenticate with gcloud
gcloud auth configure-docker us-east1-docker.pkg.dev

# Push to Artifact Registry (the successor to GCR)
docker tag myapp:1.4.2 us-east1-docker.pkg.dev/my-project/my-repo/myapp:1.4.2
docker push us-east1-docker.pkg.dev/my-project/my-repo/myapp:1.4.2
```

#### Azure Container Registry (ACR)

```bash
# Authenticate
az acr login --name myregistry

# Push
docker tag myapp:1.4.2 myregistry.azurecr.io/myapp:1.4.2
docker push myregistry.azurecr.io/myapp:1.4.2

# Enable geo-replication (enterprise feature — replicate images to multiple regions)
az acr replication create --registry myregistry --location eastus
az acr replication create --registry myregistry --location westeurope
```

#### Registry Comparison

| Feature | Docker Hub | AWS ECR | Google AR | Azure ACR |
|---|---|---|---|---|
| Free private repos | 1 | Unlimited (pay per GB) | Pay per GB | 1 (Basic tier) |
| Geo-replication | No (paid) | Yes (multi-region) | Yes (global) | Yes (Premium) |
| Vulnerability scanning | Yes (Scout) | Yes (Inspector) | Yes (Artifact Analysis) | Yes (Defender) |
| K8s auth integration | Pull secret | IRSA / EC2 role | Workload Identity | Managed Identity |
| Image signing | Cosign | Cosign + ECR sign | Cosign | Notation |
| Retention policies | No | Yes (lifecycle) | Yes | Yes |

---

### 2.11 The Container Runtime Interface (CRI)

The Container Runtime Interface is the bridge that connects Kubernetes to the container ecosystem. Understanding CRI explains why Docker knowledge remains relevant even though Kubernetes no longer uses Docker directly.

#### The CRI Architecture

```
┌─────────────────────────────────────────────────┐
│  Kubernetes Control Plane                        │
│                                                  │
│  kube-apiserver → kubelet                        │
└────────────────────┬────────────────────────────┘
                     │ CRI (gRPC)
                     │
          ┌──────────▼──────────┐
          │  CRI Runtime        │
          │  (choose one):      │
          │                     │
          │  ┌───────────────┐  │
          │  │ containerd    │  │  ← Default in most managed K8s (EKS, GKE, AKS)
          │  └───────┬───────┘  │
          │          │ OCI      │
          │  ┌───────▼───────┐  │
          │  │   CRI-O       │  │  ← OpenShift default; strictly Kubernetes-focused
          │  └───────────────┘  │
          └──────────┬──────────┘
                     │ OCI Runtime Spec
                     │
          ┌──────────▼──────────┐
          │  OCI Runtime        │
          │  runc / crun        │  ← Makes the actual syscalls (clone, mount, etc.)
          └─────────────────────┘
```

#### What Happened to dockershim?

In Kubernetes 1.20, `dockershim` was deprecated. In Kubernetes 1.24 (May 2022), it was removed. The `dockershim` was an in-tree shim that let `kubelet` talk to `dockerd` before CRI was standardized. Its removal does not mean Docker is gone:

- Container images built with Docker are OCI-compliant and run on any CRI runtime.
- `containerd` is the runtime at the heart of Docker. Kubernetes using `containerd` directly is more efficient than going through `dockerd`.
- `docker build` and `docker push` are still the dominant image build tools.

```
BEFORE (Kubernetes ≤ 1.23):
kubelet → dockershim → dockerd → containerd → runc

AFTER (Kubernetes ≥ 1.24):
kubelet → CRI → containerd → runc   (one fewer hop; lower latency; less memory)
```

#### crictl — The kubelet-side Debug Tool

Once you are on a Kubernetes node, `docker` CLI is not available (the node runs `containerd`, not `dockerd`). Use `crictl` instead:

```bash
# crictl is the CRI-compatible equivalent of docker CLI for node-level debugging

# List running containers (equivalent to: docker ps)
crictl ps

# List images on this node (equivalent to: docker images)
crictl images

# Pull an image (equivalent to: docker pull)
crictl pull nginx:alpine

# Get container logs (equivalent to: docker logs)
crictl logs <container-id>

# Execute a command in a container (equivalent to: docker exec)
crictl exec -it <container-id> sh

# Inspect a container
crictl inspect <container-id>

# List pods (Kubernetes-specific — no Docker equivalent)
crictl pods

# Node-level image garbage collection status
crictl imagefsinfo
```

#### OCI Standards — Why Image Portability Works

The Open Container Initiative (OCI) defines two specifications that make the container ecosystem interoperable:

| OCI Spec | What It Defines | Ensures |
|---|---|---|
| Image Spec | Image manifest format, layer format, config schema | Images built with Docker run on containerd, CRI-O, or Podman |
| Runtime Spec | Container configuration and execution environment | `runc`, `crun`, `gVisor`, `Kata` all accept the same container config |

---

## 3. Step-by-Step Hands-on Walkthrough

### 3.1 Build a Production-Grade Multi-Stage Image

We will build a production-ready Node.js API image from scratch, applying every technique covered in this chapter.

```bash
# Project structure
mkdir k8s-demo-api && cd k8s-demo-api

cat > package.json << 'EOF'
{
  "name": "k8s-demo-api",
  "version": "1.0.0",
  "scripts": { "start": "node src/server.js" },
  "dependencies": { "express": "^4.18.2" }
}
EOF

mkdir src
cat > src/server.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/health', (req, res) => res.json({ status: 'ok', version: '1.0.0' }));
app.get('/', (req, res) => res.json({ message: 'Hello from Kubernetes!', env: process.env.APP_ENV }));

app.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
EOF
```

```dockerfile
# Dockerfile (multi-stage, production-grade)
# ─── Stage 1: Install dependencies ───────────────────────────────
FROM node:20.11-alpine3.19 AS deps
RUN apk add --no-cache dumb-init
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# ─── Stage 2: Production image ───────────────────────────────────
FROM node:20.11-alpine3.19 AS production

# Security: run as non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

# Copy dumb-init from deps stage
COPY --from=deps /usr/bin/dumb-init /usr/bin/dumb-init

# Copy only production node_modules
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodejs:nodejs src/ ./src/
COPY --chown=nodejs:nodejs package.json ./

USER nodejs

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]
```

```bash
# Build the image
docker build -t k8s-demo-api:1.0.0 .

# Verify the image size
docker images k8s-demo-api
# REPOSITORY      TAG     IMAGE ID       SIZE
# k8s-demo-api    1.0.0   a3f9b2c1d4e5   82.1MB

# Inspect the layers
docker history k8s-demo-api:1.0.0

# Scan for vulnerabilities
docker scout cves k8s-demo-api:1.0.0
# OR
trivy image k8s-demo-api:1.0.0

# Run locally to verify
docker run -d \
  --name demo-api \
  -e APP_ENV=development \
  -p 3000:3000 \
  k8s-demo-api:1.0.0

curl http://localhost:3000/health
# {"status":"ok","version":"1.0.0"}

curl http://localhost:3000/
# {"message":"Hello from Kubernetes!","env":"development"}
```

---

### 3.2 Set Up a Full Local Environment with Docker Compose

```yaml
# docker-compose.dev.yml — development overrides
services:
  api:
    build:
      context: .
      target: production
    image: k8s-demo-api:dev
    ports:
      - "3000:3000"
    environment:
      - APP_ENV=development
      - PORT=3000
    volumes:
      - ./src:/app/src:ro          # Mount source for development visibility
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 5s
```

```bash
# Start the local environment
docker compose -f docker-compose.dev.yml up -d --build

# Verify services are healthy
docker compose ps
# NAME        IMAGE              STATUS          PORTS
# demo-api    k8s-demo-api:dev   Up (healthy)    0.0.0.0:3000->3000/tcp

# Follow logs
docker compose logs -f api

# Clean up
docker compose -f docker-compose.dev.yml down
```

---

### 3.3 Push to a Registry and Pull in Kubernetes

```bash
# Tag for your registry (replace with your actual registry)
docker tag k8s-demo-api:1.0.0 ghcr.io/myorg/k8s-demo-api:1.0.0

# Push
docker push ghcr.io/myorg/k8s-demo-api:1.0.0

# Get the immutable digest
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/myorg/k8s-demo-api:1.0.0
# ghcr.io/myorg/k8s-demo-api@sha256:3d88c5de...

# Create a Kubernetes imagePullSecret for a private registry
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=myorg \
  --docker-password=$GITHUB_TOKEN \
  --namespace=devops-demo
```

```yaml
# deployment-with-registry.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-demo-api
  namespace: devops-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: k8s-demo-api
  template:
    metadata:
      labels:
        app: k8s-demo-api
    spec:
      # Reference the imagePullSecret for private registries
      imagePullSecrets:
        - name: regcred
      containers:
        - name: api
          # Use immutable digest in production (not a mutable tag)
          image: ghcr.io/myorg/k8s-demo-api@sha256:3d88c5de...
          ports:
            - containerPort: 3000
          env:
            - name: APP_ENV
              value: production
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
```

```bash
kubectl apply -f deployment-with-registry.yaml
kubectl rollout status deployment/k8s-demo-api
kubectl get pods -l app=k8s-demo-api
```

---

## 4. Real-World Scenario: Migrating a Legacy Java App to Containers

### The Problem

FinCo's core processing service is a Spring Boot 2.7 application deployed to bare metal with manual JAR transfers via SCP. The team has no container experience. The application has three major containerization challenges:

- JVM memory management was tuned for bare metal (fixed 4GB heap on 8GB hosts); in containers this causes OOM kills.
- Configuration is stored in `application.properties` files managed manually per environment.
- The team runs the same JAR on dev laptops and production, but the Ubuntu version differs, causing occasional GLIBC errors.

### The Solution

**Phase 1 — Containerize with multi-stage build:**

```dockerfile
FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src/ ./src/
RUN mvn clean package -DskipTests -B

FROM eclipse-temurin:21-jre-alpine AS production
RUN addgroup -g 1001 -S spring && adduser -u 1001 -S spring -G spring
WORKDIR /app
COPY --from=builder --chown=spring:spring /build/target/*.jar app.jar
USER spring
EXPOSE 8080
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]
```

**Phase 2 — Externalize configuration:**

Replace hardcoded `application.properties` values with environment variable bindings (`${DB_URL}`), injected via Kubernetes ConfigMaps and Secrets.

**Phase 3 — Validate in Docker Compose before Kubernetes:**

The team writes a `docker-compose.yml` that mirrors the production topology (app + PostgreSQL + Redis), allowing local integration testing before deploying to the cluster.

### Results

| Issue | Before | After |
|---|---|---|
| JVM OOM kills in containers | Constant (heap > limit) | Zero (`MaxRAMPercentage=75.0`) |
| Dev/prod environment parity | Broken (GLIBC differences) | Perfect (same Alpine base) |
| Deploy time | 20 min (manual SCP + restart) | 90 sec (Docker push + kubectl apply) |
| Image size | N/A (JAR only) | 187 MB (JRE + app) |
| Environment config management | 6 hand-edited .properties files | 1 ConfigMap + 1 Secret |

---

## 5. Common Pitfalls & Best Practices

### Pitfall 1: Running as Root Inside Containers
The default user in most base images is root (UID 0). A container escape vulnerability combined with root privileges can compromise the host. Always create and switch to a non-root user. In Kubernetes, enforce this with `runAsNonRoot: true` in the Pod `securityContext`.

### Pitfall 2: Building with `COPY . .` Before Installing Dependencies
This invalidates the dependency layer cache on every code change, turning a 30-second cached build into a 5-minute full rebuild. Always copy dependency manifests (`package.json`, `go.mod`, `pom.xml`) and install dependencies before copying source code.

### Pitfall 3: Storing Secrets in Docker Images
Using `ENV SECRET_KEY=mypassword` or `COPY .env .` bakes secrets permanently into the image layer history. Anyone with `docker history` access can extract them. Inject secrets at runtime via environment variables, Kubernetes Secrets, or a secrets manager.

### Pitfall 4: Ignoring `.dockerignore`
Without a `.dockerignore`, `docker build` sends your entire project directory (including `.git`, `node_modules`, test fixtures, and local `.env` files) to the Docker daemon as build context. This slows builds and risks leaking sensitive files into the image.

### Pitfall 5: Using Mutable Tags in Kubernetes Deployments
Using `image: myapp:latest` in a Kubernetes Deployment means different nodes may pull different versions of the same tag, creating split-brain deployments. Use immutable tags (semantic versions or Git SHAs) or SHA digests in all Kubernetes manifests.

### Pitfall 6: Ignoring Image Vulnerability Scanning
A base image like `node:18` can carry 300+ known CVEs, many HIGH or CRITICAL. Integrate Trivy or Grype into your CI pipeline as a blocking step. Failing on HIGH+ severity CVEs before pushing to your registry is far cheaper than remediating them post-deployment.

> **Best Practice Checklist — Docker for Kubernetes**
> - [ ] Use multi-stage builds for all production images
> - [ ] Run containers as non-root (UID ≥ 1000)
> - [ ] Pin base image tags to exact versions, not `latest`
> - [ ] Add a comprehensive `.dockerignore` to every project
> - [ ] Never store secrets in images (`ENV`, `COPY .env`, `ARG` with secrets)
> - [ ] Scan every image in CI with Trivy or Grype before pushing
> - [ ] Use `dumb-init` or `tini` as PID 1 for proper signal handling
> - [ ] Set `HEALTHCHECK` in Dockerfile (documents intent; Kubernetes uses probes)
> - [ ] Use immutable image tags (semantic version or Git SHA) in K8s manifests
> - [ ] Combine `apt-get update && apt-get install && apt-get clean` in one `RUN`

---

## 6. Key Takeaways

1. **Containers are Linux processes**, not VMs. They achieve isolation through kernel namespaces and resource enforcement through cgroups — the same mechanisms Kubernetes uses under the hood. Understanding this model makes Kubernetes resource limits intuitive, not magical.

2. **Image layers are the fundamental unit of caching and sharing.** Ordering Dockerfile instructions from least-frequently-changed to most-frequently-changed (base → dependencies → source) is the single most impactful build performance optimization.

3. **Multi-stage builds are non-negotiable for production.** They separate build tooling from runtime artifacts, dramatically reduce image size, and minimize the attack surface exposed in production.

4. **`.dockerignore` is not optional.** A missing `.dockerignore` slows builds, increases image size, and risks leaking secrets and local configuration files into your container images.

5. **Docker Hub, ECR, GCR, and ACR all serve the same role** — OCI-compliant image registries — but differ in their authentication model, Kubernetes integration depth, scanning capabilities, and cost. Choose based on your cloud provider and compliance requirements.

6. **Docker is still fully relevant in a Kubernetes world.** The removal of `dockershim` in Kubernetes 1.24 did not remove Docker from the picture — it removed an unnecessary translation layer. OCI-compliant images built with Docker run on `containerd` without modification. On Kubernetes nodes, use `crictl` instead of `docker` for runtime debugging.

---

## 7. Exercises & Labs

**Exercise 1: Multi-Stage Build Comparison**
Build the same Node.js application twice: once using a naive single-stage Dockerfile (`FROM node:20`, `COPY . .`, `RUN npm install`) and once using the multi-stage pattern from Section 3.1. Compare the image sizes using `docker images` and the layer breakdown using `docker history`. Document the size difference and identify which layers account for the savings.

**Exercise 2: Layer Cache Analysis**
Start with the naive Dockerfile from Exercise 1. Make a small change to `src/server.js` (add a comment) and rebuild. Observe how many layers are rebuilt. Then rebuild with the optimized Dockerfile. Compare the number of layers rebuilt and the rebuild times. Write a one-paragraph explanation of why the ordering change has such a large impact.

**Exercise 3: Docker Compose Full Stack**
Using the Docker Compose configuration from Section 2.9 as a template, build a local environment for a three-service application: a Node.js API, a PostgreSQL database, and a Redis cache. Add health checks to all services. Configure the API to depend on the database with `condition: service_healthy`. Verify the startup order is correct by watching `docker compose up` logs.

**Exercise 4: Registry Push and imagePullSecret**
Create a free account on Docker Hub (or use an existing one). Build the `k8s-demo-api` image from Section 3.1, push it to your Docker Hub account, and then deploy it to your minikube cluster using the `imagePullSecret` pattern from Section 3.3. Verify the Pod starts successfully and the correct image is running using `kubectl describe pod`.

**Exercise 5: crictl Node Debugging**
SSH into your minikube node using `minikube ssh`. Use `crictl` to: (a) list all running containers, (b) inspect the Pod sandbox for one of your running Pods, (c) retrieve the last 50 lines of logs from a running container, and (d) execute `env` inside a running container to verify environment variables from a ConfigMap are correctly injected. Write a brief comparison of the `crictl` commands you used versus their `docker` CLI equivalents.

---

*End of Chapter 2*

**Next → Chapter 3: Speeding Up with Standard Kubernetes Operations**
