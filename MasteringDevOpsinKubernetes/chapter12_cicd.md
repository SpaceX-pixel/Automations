# Chapter 12 — Continuous Development and Continuous Deployment

> *Mastering DevOps in Kubernetes*
> GitHub Actions · Jenkins X · CI Pipeline Design · Security Gates · Progressive Delivery · Argo Rollouts

---

## 1. Introduction & Learning Objectives

Continuous Integration and Continuous Deployment are the operational heartbeat of any high-performing engineering organisation. In the Kubernetes world, CI/CD is not just about automating `kubectl apply` — it is about building a complete delivery system that takes code from a developer's laptop to production with confidence, speed, and auditability. Every pipeline stage is a quality gate; every gate that passes is an assertion that the software is safe to move to the next environment.

The modern Kubernetes CI/CD pipeline must do far more than compile code and push images. It must prove the software is correct (unit and integration tests), prove it is secure (SAST, dependency scanning, image scanning), prove it meets operational requirements (resource limits, security contexts, policy compliance), and then deploy it in a way that allows early detection of regressions before the full user base is affected (canary deployments, traffic shifting, automated analysis).

This chapter builds three complete, production-grade CI/CD systems — one with GitHub Actions (the most widely used developer-facing CI platform), one with Jenkins X (the Kubernetes-native GitOps CI/CD platform), and one revisiting the Azure DevOps pipeline from Chapter 6 with deeper coverage of multi-stage deployment strategies. We then deep-dive progressive delivery patterns using Argo Rollouts: canary with automated analysis, blue/green with manual promotion gates, and traffic mirroring for zero-risk validation.

> **Learning Objectives**
> - Design a CI/CD pipeline that separates concerns cleanly across build, test, scan, publish, and deploy stages.
> - Build a production-grade GitHub Actions workflow with reusable workflows, composite actions, and OIDC authentication.
> - Implement a Jenkins X pipeline with Tekton-based build packs and automated environment promotion.
> - Integrate security scanning gates: SAST with CodeQL, dependency scanning with Dependabot and Snyk, image scanning with Trivy, and Kubernetes manifest validation with Polaris.
> - Implement automated test stages: unit, integration with testcontainers, and post-deploy smoke tests.
> - Design canary and blue/green deployment strategies using Argo Rollouts with Prometheus-based automated analysis.
> - Configure traffic mirroring (shadow mode) for zero-risk production validation.
> - Build a complete end-to-end pipeline from `git push` to production with every quality gate instrumented and observable.

---

## 2. Core Concepts

### 2.1 CI/CD Pipeline Architecture for Kubernetes

A well-designed Kubernetes CI/CD pipeline has a clear separation of concerns across three domains: **CI** (build, test, scan, publish), **CD** (deploy to environments, run post-deploy tests), and **delivery** (control how traffic reaches the new version).

```
┌──────────────────────────────────────────────────────────────────────────┐
│  CONTINUOUS INTEGRATION              CONTINUOUS DEPLOYMENT               │
│  (triggered by git push)             (triggered by CI success)           │
│                                                                           │
│  ┌─────────────────────────────┐    ┌────────────────────────────────┐  │
│  │  1. Source                  │    │  4. Deploy — Development        │  │
│  │     Checkout, lint, SAST    │    │     kubectl / Argo CD / Flux    │  │
│  │     dependency audit        │    │     Smoke tests                 │  │
│  │                             │    │                                  │  │
│  │  2. Build                   │    │  5. Deploy — Staging            │  │
│  │     Docker multi-stage      │    │     Integration tests           │  │
│  │     Layer cache optimisation│    │     Performance baseline        │  │
│  │                             │    │                                  │  │
│  │  3. Verify                  │    │  6. Deploy — Production         │  │
│  │     Unit tests              │    │     Progressive delivery        │  │
│  │     Integration tests       │    │     ┌── Canary (5%→20%→100%)  │  │
│  │     Image scan (Trivy)      │    │     ├── Blue/Green (instant)   │  │
│  │     SBOM generation         │    │     └── Traffic mirror          │  │
│  │     Manifest validation     │    │     Automated analysis          │  │
│  │     Push to registry        │    │     Rollback on failure         │  │
│  └─────────────────────────────┘    └────────────────────────────────┘  │
│                                                                           │
│  QUALITY GATES (each gate is a pass/fail assertion)                      │
│  ─────────────────────────────────────────────────────────────────────   │
│  ✓ All tests pass    ✓ No CRITICAL CVEs    ✓ Policy compliant            │
│  ✓ Coverage >80%     ✓ No secrets in code  ✓ Signed image                │
│  ✓ Lint clean        ✓ SBOM generated      ✓ Canary analysis pass        │
└──────────────────────────────────────────────────────────────────────────┘
```

#### The Twelve Principles of Kubernetes CI/CD

1. **Immutable artifacts** — build once, deploy the same binary everywhere. No environment-specific builds.
2. **Fail fast** — cheap gates (lint, compile) run first; expensive gates (integration, scan) run after.
3. **Every pipeline run is reproducible** — pinned tool versions, hermetic builds, no network calls during tests.
4. **Security is not a final gate** — scanning runs in the inner loop (on every PR), not just before release.
5. **Test coverage is a first-class metric** — coverage gates block merges, not just report.
6. **Images are signed** — every production image has a cryptographic attestation.
7. **No `latest` tags** — every image reference in manifests is an immutable tag or digest.
8. **GitOps for deployment** — pipelines write to Git; agents deploy from Git.
9. **Every deployment is observable** — Prometheus metrics gate progressive delivery.
10. **Every deployment is reversible** — rollback takes under 2 minutes.
11. **Secrets never appear in logs or environment variables** — use OIDC, Workload Identity, or mounted files.
12. **Pipeline configuration is code** — pipeline YAML lives in the same repo as the application code.

---

### 2.2 Progressive Delivery Strategies

Before building the pipelines, we must be precise about the deployment strategies they implement.

```
Strategy         Traffic distribution     Rollback speed    Complexity
─────────────────────────────────────────────────────────────────────────
Recreate         0% → 100% (hard switch)  Full redeploy      Low
                 ↳ Downtime during switch
                 ↳ Use only for breaking changes in dev

RollingUpdate    Old Pods replaced        kubectl rollout    Low
                 incrementally            undo (seconds)
                 ↳ Default K8s strategy
                 ↳ No traffic control

Blue/Green       100% blue → 100% green   Service selector   Medium
                 (instant cutover)        flip (seconds)
                 ↳ Need 2x resources
                 ↳ Instant rollback

Canary           5% → 20% → 50% → 100%   Weight back to 0   Medium
                 (gradual traffic shift)  (seconds)
                 ↳ Real traffic validation
                 ↳ Automated Prometheus analysis

Traffic Mirror   100% to stable           N/A — mirror only  High
                 + shadow copy to canary  no rollback needed
                 ↳ Zero-risk validation
                 ↳ Canary gets real requests, responses ignored
```

---

### 2.3 Argo Rollouts Architecture

Argo Rollouts replaces the Kubernetes Deployment resource with a `Rollout` resource that understands traffic shifting, progressive delivery, and automated metric analysis.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Argo Rollouts Controller                                             │
│                                                                       │
│  Rollout resource → manages:                                          │
│  ├── ReplicaSet (stable)    ← current version, receives most traffic  │
│  ├── ReplicaSet (canary)    ← new version, receives canary traffic    │
│  │                                                                    │
│  └── Traffic management:                                              │
│       ├── Weighted Services (native K8s, coarse-grained)             │
│       ├── NGINX Ingress annotations                                   │
│       ├── Istio VirtualService (precise % splitting)                 │
│       ├── AWS Load Balancer Controller (ALB weighted target groups)  │
│       └── Gateway API (SMI-compatible)                               │
│                                                                       │
│  AnalysisRun → evaluates:                                             │
│  ├── Prometheus queries (error rate, latency, business metrics)      │
│  ├── Datadog metrics                                                  │
│  ├── CloudWatch metrics                                              │
│  ├── Web hook checks (external validation services)                  │
│  └── Job-based analysis (custom scripts)                             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. GitHub Actions — Complete CI/CD Pipeline

### 3.1 Repository Structure

```
.github/
├── workflows/
│   ├── ci.yml                    ← Main CI pipeline (PR + main branch)
│   ├── cd-staging.yml            ← Deploy to staging on main merge
│   ├── cd-production.yml         ← Deploy to production (manual trigger)
│   ├── security-scan.yml         ← Scheduled security scans
│   └── dependency-update.yml     ← Auto dependency PRs
├── actions/
│   ├── build-push/
│   │   └── action.yml            ← Composite action: build + push image
│   ├── helm-deploy/
│   │   └── action.yml            ← Composite action: helm upgrade
│   └── smoke-test/
│       └── action.yml            ← Composite action: run smoke tests
└── CODEOWNERS                    ← Require platform team approval for pipeline changes
```

### 3.2 Reusable Workflow — Build and Scan

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, 'release/**']
  pull_request:
    branches: [main]
  workflow_dispatch:

# Cancel in-progress runs when a newer commit is pushed
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository_owner }}/order-api
  NODE_VERSION: "20"
  HELM_VERSION: "3.15.0"

jobs:
  # ────────────────────────────────────────────────────────────────────
  # Job 1: Lint and Static Analysis
  # Fast — runs in parallel with nothing, blocks everything else
  # ────────────────────────────────────────────────────────────────────
  lint-and-sast:
    name: Lint and Static Analysis
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      security-events: write    # For uploading SARIF to GitHub Security
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0          # Full history for better diff analysis

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Lint (ESLint)
        run: npm run lint -- --format=@microsoft/eslint-formatter-sarif \
               --output-file eslint-results.sarif
        continue-on-error: true

      - name: Upload ESLint SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: eslint-results.sarif
          category: eslint

      - name: CodeQL Analysis (SAST)
        uses: github/codeql-action/init@v3
        with:
          languages: javascript
          queries: security-and-quality

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: codeql-javascript
          upload: true

      - name: Gitleaks — Secret Scanning
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

      - name: Validate Kubernetes manifests (Helm template + Polaris)
        run: |
          # Install tools
          curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
            | DESIRED_VERSION=v${HELM_VERSION} bash
          curl -fsSL https://github.com/FairwindsOps/polaris/releases/latest/download/polaris_linux_amd64.tar.gz \
            | tar xz && mv polaris /usr/local/bin/

          # Render Helm templates for all environments
          for env in development staging production; do
            echo "=== Validating $env ==="
            helm template order-api ./helm/order-api \
              --values ./helm/order-api/values.yaml \
              --values ./helm/order-api/values-${env}.yaml \
              | polaris audit \
                  --audit-path /dev/stdin \
                  --format score \
                  --set-exit-code-below-score 75
          done

  # ────────────────────────────────────────────────────────────────────
  # Job 2: Unit Tests with Coverage
  # ────────────────────────────────────────────────────────────────────
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: lint-and-sast
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests with coverage
        run: |
          npm run test:unit -- \
            --coverage \
            --coverageReporters=lcov \
            --coverageReporters=json-summary \
            --forceExit
        env:
          NODE_ENV: test

      - name: Coverage gate (minimum 80%)
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | \
            jq '.total.lines.pct')
          echo "Line coverage: ${COVERAGE}%"
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "::error::Coverage ${COVERAGE}% is below the 80% threshold"
            exit 1
          fi

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: true
          token: ${{ secrets.CODECOV_TOKEN }}

      - name: Publish test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Unit Test Results
          path: test-results/junit.xml
          reporter: jest-junit

  # ────────────────────────────────────────────────────────────────────
  # Job 3: Integration Tests (with testcontainers)
  # ────────────────────────────────────────────────────────────────────
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: unit-tests
    services:
      # GitHub Actions services run as Docker containers alongside the job
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: orders_test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: testpassword
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Run database migrations
        run: npm run migrate:up
        env:
          DATABASE_URL: postgresql://postgres:testpassword@localhost:5432/orders_test

      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:testpassword@localhost:5432/orders_test
          REDIS_URL: redis://localhost:6379
          NODE_ENV: test

      - name: Publish integration test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Integration Test Results
          path: test-results/integration-junit.xml
          reporter: jest-junit

  # ────────────────────────────────────────────────────────────────────
  # Job 4: Build and Push Container Image
  # Only runs on push to main or release branches
  # ────────────────────────────────────────────────────────────────────
  build-and-push:
    name: Build and Push Image
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: integration-tests
    if: github.event_name == 'push'
    permissions:
      contents: read
      packages: write
      id-token: write       # Required for OIDC (keyless signing)
      security-events: write
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
      image-tag: ${{ steps.meta.outputs.version }}
      full-image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          install: true

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract image metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            # Tag with short commit SHA (always)
            type=sha,prefix=,format=short
            # Tag with branch name (sanitised)
            type=ref,event=branch
            # Tag with semantic version if pushed as tag
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
          labels: |
            org.opencontainers.image.title=Order API
            org.opencontainers.image.vendor=MyCompany
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}

      - name: Build and push image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: |
            type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:cache
            type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main
          cache-to: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:cache,mode=max
          # Multi-platform build
          platforms: linux/amd64,linux/arm64
          provenance: true         # Generate SLSA provenance attestation
          sbom: true               # Generate SBOM attestation

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: 1
          ignore-unfixed: true

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-results.sarif
          category: trivy

      - name: Sign image with Cosign (keyless OIDC)
        uses: sigstore/cosign-installer@v3

      - name: Sign and attest the image
        run: |
          # Sign the image (keyless, using GitHub OIDC)
          cosign sign \
            --yes \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

          # Attach the Trivy vulnerability scan as an attestation
          cosign attest \
            --yes \
            --predicate trivy-results.sarif \
            --type vuln \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

      - name: Verify the signature
        run: |
          cosign verify \
            --certificate-identity-regexp="https://github.com/${{ github.repository }}/*" \
            --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

  # ────────────────────────────────────────────────────────────────────
  # Job 5: Dependency Audit
  # Runs in parallel with integration tests
  # ────────────────────────────────────────────────────────────────────
  dependency-audit:
    name: Dependency Audit
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: lint-and-sast
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: npm

      - name: npm audit (block on high/critical)
        run: npm audit --audit-level=high

      - name: Snyk dependency scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --fail-on=all

      - name: License compliance check
        run: |
          npx license-checker \
            --production \
            --excludePrivatePackages \
            --failOn "GPL-2.0;GPL-3.0;AGPL-3.0"  # Block copyleft licenses
```

### 3.3 CD Workflow — Staging Deploy

```yaml
# .github/workflows/cd-staging.yml
name: CD — Staging Deployment

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]
    branches: [main]

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    timeout-minutes: 15
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    environment:
      name: staging
      url: https://staging.api.mycompany.com

    permissions:
      contents: read
      id-token: write     # OIDC for cloud authentication

    steps:
      - uses: actions/checkout@v4

      - name: Download CI artifacts (image digest)
        uses: actions/download-artifact@v4
        with:
          name: image-metadata
          github-token: ${{ secrets.GITHUB_TOKEN }}
          run-id: ${{ github.event.workflow_run.id }}

      - name: Read image digest
        id: image
        run: |
          DIGEST=$(cat image-digest.txt)
          TAG=$(cat image-tag.txt)
          echo "digest=$DIGEST" >> $GITHUB_OUTPUT
          echo "tag=$TAG" >> $GITHUB_OUTPUT

      # Authenticate to cloud using OIDC — no stored credentials
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-staging
          aws-region: us-east-1

      - name: Update kubeconfig for staging EKS
        run: |
          aws eks update-kubeconfig \
            --name staging-eks \
            --region us-east-1

      - name: Install Helm
        uses: azure/setup-helm@v4
        with:
          version: ${{ env.HELM_VERSION }}

      - name: Helm upgrade (staging)
        run: |
          helm upgrade --install order-api \
            oci://ghcr.io/${{ github.repository_owner }}/helm-charts/order-api \
            --version 1.4.2 \
            --namespace staging \
            --create-namespace \
            --values helm/order-api/values.yaml \
            --values helm/order-api/values-staging.yaml \
            --set image.repository=ghcr.io/${{ env.IMAGE_NAME }} \
            --set image.digest=${{ steps.image.outputs.digest }} \
            --set image.tag="" \
            --wait \
            --timeout 5m \
            --atomic \
            --history-max 5

      - name: Run smoke tests
        run: |
          # Wait for Ingress to be ready
          kubectl wait ingress/order-api \
            --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
            --namespace staging \
            --timeout=120s

          STAGING_URL=$(kubectl get ingress order-api \
            -n staging \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

          # Run smoke test suite
          SMOKE_BASE_URL="https://${STAGING_URL}" npm run test:smoke

      - name: Post deployment summary
        if: always()
        run: |
          echo "## Staging Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "| Field | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|-------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Image | \`${{ steps.image.outputs.tag }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| Digest | \`${{ steps.image.outputs.digest }}\` |" >> $GITHUB_STEP_SUMMARY
          echo "| Environment | staging |" >> $GITHUB_STEP_SUMMARY
          echo "| Status | ${{ job.status }} |" >> $GITHUB_STEP_SUMMARY
```

### 3.4 CD Workflow — Production with Progressive Delivery

```yaml
# .github/workflows/cd-production.yml
name: CD — Production Deployment

on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag to deploy (from CI pipeline)"
        required: true
        type: string
      deployment_strategy:
        description: "Deployment strategy"
        required: true
        type: choice
        options: [canary, blue-green, rolling]
        default: canary
      canary_steps:
        description: "Comma-separated canary weights (e.g. 5,20,50,100)"
        required: false
        default: "5,20,50,100"

jobs:
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    timeout-minutes: 30
    environment:
      name: production
      url: https://api.mycompany.com
    # Requires 2 approvals (configured in GitHub Environment settings)

    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-production
          aws-region: us-east-1

      - name: Update kubeconfig for production EKS
        run: |
          aws eks update-kubeconfig \
            --name production-eks \
            --region us-east-1

      - name: Verify image signature before production deploy
        run: |
          cosign verify \
            --certificate-identity-regexp="https://github.com/${{ github.repository }}/*" \
            --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
            ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }}
          echo "Image signature verified ✓"

      - name: Install kubectl-argo-rollouts plugin
        run: |
          curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
          chmod +x kubectl-argo-rollouts-linux-amd64
          sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

      - name: Deploy with canary strategy (Argo Rollouts)
        if: inputs.deployment_strategy == 'canary'
        run: |
          # Update the Rollout image
          kubectl argo rollouts set image order-api \
            order-api=ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }} \
            -n production

          # Watch the rollout progress
          kubectl argo rollouts status order-api \
            -n production \
            --timeout 20m

      - name: Deploy with blue/green strategy
        if: inputs.deployment_strategy == 'blue-green'
        run: |
          kubectl argo rollouts set image order-api \
            order-api=ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }} \
            -n production

          # Wait for preview environment to be ready
          kubectl argo rollouts status order-api \
            -n production \
            --timeout 10m

          echo "Blue/green preview ready. Awaiting manual promotion..."
          echo "Promote with: kubectl argo rollouts promote order-api -n production"

      - name: Post-deploy health verification
        run: |
          # Wait for all Pods to be ready
          kubectl rollout status deployment/order-api \
            -n production \
            --timeout 10m 2>/dev/null || \
          kubectl argo rollouts status order-api \
            -n production \
            --timeout 10m

          # Verify metrics are healthy post-deploy
          PROD_URL="https://api.mycompany.com"

          # Check health endpoint
          HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            --retry 5 --retry-delay 10 \
            "${PROD_URL}/health/ready")

          if [ "$HTTP_STATUS" != "200" ]; then
            echo "::error::Health check failed with status $HTTP_STATUS"
            exit 1
          fi

      - name: Create GitHub Release
        if: success()
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ inputs.image_tag }}
          release_name: "Release ${{ inputs.image_tag }}"
          body: |
            ## Deployment Summary
            - **Image:** `ghcr.io/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }}`
            - **Strategy:** ${{ inputs.deployment_strategy }}
            - **Deployed by:** @${{ github.actor }}
            - **Deployed at:** ${{ github.event.head_commit.timestamp }}
          draft: false
          prerelease: false

      - name: Notify on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": ":rotating_light: Production deployment failed!",
              "attachments": [{
                "color": "danger",
                "fields": [
                  {"title": "Image", "value": "${{ inputs.image_tag }}", "short": true},
                  {"title": "Actor", "value": "${{ github.actor }}", "short": true},
                  {"title": "Run URL", "value": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"}
                ]
              }]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 3.5 Composite Action — Build and Push

```yaml
# .github/actions/build-push/action.yml
# Reusable composite action for building and pushing images
# Used across multiple workflows to avoid duplication

name: Build and Push Container Image
description: Builds a Docker image with caching and pushes to registry

inputs:
  image-name:
    description: Full image name (e.g. ghcr.io/myorg/myapp)
    required: true
  dockerfile:
    description: Path to Dockerfile
    default: Dockerfile
  context:
    description: Docker build context
    default: .
  push:
    description: Whether to push the image
    default: 'true'
  registry-username:
    description: Registry username
    required: true
  registry-password:
    description: Registry password or token
    required: true

outputs:
  digest:
    description: Image digest
    value: ${{ steps.build.outputs.digest }}
  tags:
    description: Image tags
    value: ${{ steps.meta.outputs.tags }}

runs:
  using: composite
  steps:
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
      with:
        install: true

    - name: Login to registry
      uses: docker/login-action@v3
      with:
        registry: ${{ fromJSON(inputs.image-name).registry || 'docker.io' }}
        username: ${{ inputs.registry-username }}
        password: ${{ inputs.registry-password }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ inputs.image-name }}
        tags: |
          type=sha,prefix=,format=short
          type=ref,event=branch
          type=semver,pattern={{version}}

    - name: Build and push
      id: build
      uses: docker/build-push-action@v5
      with:
        context: ${{ inputs.context }}
        file: ${{ inputs.dockerfile }}
        push: ${{ inputs.push }}
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=registry,ref=${{ inputs.image-name }}:cache
        cache-to: type=registry,ref=${{ inputs.image-name }}:cache,mode=max
        platforms: linux/amd64,linux/arm64
        provenance: true
        sbom: true
```

---

## 4. Jenkins X — Kubernetes-Native CI/CD

### 4.1 Jenkins X Architecture

Jenkins X is a cloud-native CI/CD platform built entirely on Kubernetes. Unlike traditional Jenkins, it uses **Tekton** as the pipeline execution engine, **Argo CD** or **Flux** for GitOps, and **Lighthouse** for Git webhook handling.

```
Developer pushes code
    │
    ▼
Lighthouse (webhook handler)
    │ Creates PipelineRun
    ▼
Tekton Pipeline (runs in Kubernetes as Pods)
    ├── clone-source     (git clone)
    ├── run-tests        (npm test)
    ├── build-image      (kaniko — no Docker daemon)
    ├── scan-image       (trivy)
    ├── push-image       (to registry)
    └── promote          (PR to environment repo)
    │
    ▼
Environment Repository (GitOps repo)
    │ Pull Request opened/merged
    ▼
Argo CD / Flux (reconciles cluster to Git state)
    │
    ▼
Kubernetes Cluster
    └── Application deployed
```

### 4.2 Jenkins X Installation

```bash
# Install jx CLI
brew tap jenkins-x/jx
brew install jx

# Install Jenkins X on an existing Kubernetes cluster
# Jenkins X uses a GitOps approach — all config stored in Git
jx operator install

# Or bootstrap Jenkins X with a new Git repository
jx project create \
  --git-provider-url=https://github.com \
  --git-owner=myorg \
  --git-repo-name=jx-cluster-config \
  --env-git-owner=myorg \
  --cluster my-eks-cluster \
  --domain mycompany.com

# Create a new application with build pack
jx project create \
  --pack=javascript \
  --name=order-api \
  --org=myorg

# Jenkins X creates:
# - Application repository with Dockerfile, charts/, Makefile
# - Jenkinsfile (jenkins-x.yml) with pipeline definition
# - Environment repositories for staging and production
```

### 4.3 Jenkins X Pipeline (jenkins-x.yml)

```yaml
# jenkins-x.yml — Jenkins X pipeline definition (Tekton under the hood)
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: order-api-pipeline
spec:
  tasks:
    # ── PR pipeline (runs on every Pull Request) ─────────────────────
    - name: pr-pipeline
      taskRef:
        name: jx-pipeline
      params:
        - name: pipeline-kind
          value: pullrequest

---
# jenkins-x-overrides.yml — customise the build pack pipeline
apiVersion: jenkins.io/v1
kind: Scheduler
metadata:
  name: order-api-scheduler
spec:
  pipeline:
    pullRequests:
      pipeline:
        stages:
          - name: ci
            steps:
              - name: install-deps
                image: node:20-alpine
                command: npm ci

              - name: lint
                image: node:20-alpine
                command: npm run lint

              - name: unit-test
                image: node:20-alpine
                command: npm run test:unit -- --coverage
                env:
                  - name: NODE_ENV
                    value: test

              - name: coverage-gate
                image: node:20-alpine
                command: |
                  COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
                  [ $(echo "$COVERAGE >= 80" | bc) -eq 1 ] || exit 1

              - name: build-image
                image: gcr.io/kaniko-project/executor:v1.21.0
                command: /kaniko/executor
                args:
                  - --context=/workspace/source
                  - --dockerfile=/workspace/source/Dockerfile
                  - --destination=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):$(inputs.params.VERSION)
                  - --cache=true
                  - --cache-repo=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME)/cache

              - name: scan-image
                image: aquasec/trivy:latest
                command: trivy image
                args:
                  - --exit-code=1
                  - --severity=CRITICAL
                  - --ignore-unfixed
                  - $(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):$(inputs.params.VERSION)

    release:
      pipeline:
        stages:
          - name: ci-build
            steps:
              - name: install-deps
                image: node:20-alpine
                command: npm ci

              - name: test-all
                image: node:20-alpine
                command: npm run test:ci
                env:
                  - name: DATABASE_URL
                    valueFrom:
                      secretKeyRef:
                        name: order-api-test-db
                        key: url

              - name: build-and-push
                image: gcr.io/kaniko-project/executor:v1.21.0
                command: /kaniko/executor
                args:
                  - --context=/workspace/source
                  - --dockerfile=/workspace/source/Dockerfile
                  - --destination=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):$(inputs.params.VERSION)
                  - --destination=$(inputs.params.DOCKER_REGISTRY)/$(inputs.params.APP_NAME):latest
                  - --cache=true

          - name: promote-staging
            options:
              volumes:
                - name: jx-pipeline-git-github-gh
                  secret:
                    secretName: jx-pipeline-git-github-gh
            steps:
              - name: jx-promote
                image: gcr.io/jenkinsxio/jx-cli:latest
                command: jx promote
                args:
                  - --all-auto
                  - --env=staging
                  - --version=$(inputs.params.VERSION)
                  - --batch-mode
```

### 4.4 Jenkins X Environment Promotion

```bash
# Jenkins X environments are Git repositories
# Promoting to staging = opening a PR in the staging environment repo

# List environments
jx get environments
# NAME        KIND        NAMESPACE    GIT CLONE URL
# dev         Development dev          https://github.com/myorg/jx-env-dev
# staging     Staging     jx-staging   https://github.com/myorg/jx-env-staging
# production  Production  jx-prod      https://github.com/myorg/jx-env-production

# Manually promote to staging
jx promote order-api \
  --env staging \
  --version 1.4.2 \
  --batch-mode

# Promote to production with PR (requires review)
jx promote order-api \
  --env production \
  --version 1.4.2

# Watch promotion activity
jx get activity -f order-api -w

# Jenkins X environment pipeline configuration
cat > jx/environment/production/Makefile << 'EOF'
# Validate before Argo CD applies
validate:
  helm lint charts/order-api
  kubectl apply --dry-run=server -f environments/production/
EOF
```

---

## 5. Progressive Delivery with Argo Rollouts — Deep Dive

### 5.1 Installation and Setup

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify
kubectl argo rollouts version
kubectl get pods -n argo-rollouts
```

### 5.2 Canary Rollout with Automated Analysis

```yaml
# rollout-canary.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: order-api
  namespace: production
  annotations:
    # Link to Argo CD for GitOps management
    argocd.argoproj.io/managed-by: argocd
spec:
  replicas: 10
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: order-api
  template:
    metadata:
      labels:
        app: order-api
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: order-api
          image: ghcr.io/myorg/order-api:1.4.2
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 20
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}

  strategy:
    canary:
      # The stable and canary Services for traffic splitting
      stableService: order-api-stable
      canaryService: order-api-canary

      # Traffic provider (Istio VirtualService for precise splitting)
      trafficRouting:
        istio:
          virtualService:
            name: order-api-vsvc
            routes:
              - primary
          destinationRule:
            name: order-api-destrule
            canarySubsetName: canary
            stableSubsetName: stable

      steps:
        # Step 1: 5% canary traffic
        - setWeight: 5
        # Step 2: Run analysis for 10 minutes at 5%
        - pause: {duration: 10m}
        - analysis:
            templates:
              - templateName: success-rate-check
              - templateName: latency-check
            args:
              - name: service-name
                value: order-api
        # Step 3: Increase to 20%
        - setWeight: 20
        - pause: {duration: 10m}
        - analysis:
            templates:
              - templateName: success-rate-check
              - templateName: latency-check
            args:
              - name: service-name
                value: order-api
        # Step 4: Increase to 50% — pause for human review
        - setWeight: 50
        - pause: {}              # Indefinite pause; promoted manually or via CI
        # Step 5: Full rollout
        - setWeight: 100

      # Anti-affinity: don't schedule canary and stable on same node
      antiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution: {}
        preferredDuringSchedulingIgnoredDuringExecution:
          weight: 1

---
# AnalysisTemplate — success rate check
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate-check
  namespace: production
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      count: 5                   # Run 5 times (5 minutes)
      successCondition: result[0] >= 0.995   # 99.5% success rate
      failureLimit: 1            # Fail after 1 unsuccessful measurement
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            sum(
              rate(http_requests_total{
                job="{{ args.service-name }}",
                status!~"5.."
              }[1m])
            ) /
            sum(
              rate(http_requests_total{
                job="{{ args.service-name }}"
              }[1m])
            )

---
# AnalysisTemplate — P99 latency check
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-check
  namespace: production
spec:
  args:
    - name: service-name
  metrics:
    - name: p99-latency
      interval: 1m
      count: 5
      successCondition: result[0] <= 0.5     # P99 must be ≤ 500ms
      failureLimit: 2
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            histogram_quantile(0.99,
              sum(
                rate(http_request_duration_seconds_bucket{
                  job="{{ args.service-name }}"
                }[1m])
              ) by (le)
            )

---
# AnalysisTemplate — business metric check
# Canary must not reduce the order conversion rate
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: conversion-rate-check
  namespace: production
spec:
  metrics:
    - name: order-conversion-rate
      interval: 5m
      count: 3
      # The canary conversion rate must be within 5% of stable
      successCondition: >
        result[0] >= (
          scalar(
            sum(rate(orders_completed_total{version="stable"}[5m])) /
            sum(rate(checkout_started_total{version="stable"}[5m]))
          ) * 0.95
        )
      provider:
        prometheus:
          address: http://kube-prometheus-stack-prometheus.monitoring:9090
          query: |
            sum(rate(orders_completed_total{version="canary"}[5m])) /
            sum(rate(checkout_started_total{version="canary"}[5m]))
```

### 5.3 Istio VirtualService for Traffic Splitting

```yaml
# Istio VirtualService — managed by Argo Rollouts controller
# Do NOT apply manually; Argo Rollouts updates the weights automatically
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: order-api-vsvc
  namespace: production
spec:
  hosts:
    - order-api
  http:
    - name: primary
      route:
        - destination:
            host: order-api-stable
            port:
              number: 80
          weight: 100           # Argo Rollouts modifies these weights
        - destination:
            host: order-api-canary
            port:
              number: 80
          weight: 0

---
# DestinationRule — defines stable and canary subsets
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: order-api-destrule
  namespace: production
spec:
  host: order-api
  subsets:
    - name: stable
      labels:
        rollouts-pod-template-hash: stable    # Managed by Argo Rollouts
    - name: canary
      labels:
        rollouts-pod-template-hash: canary

---
# Stable Service — routes to stable ReplicaSet
apiVersion: v1
kind: Service
metadata:
  name: order-api-stable
  namespace: production
spec:
  selector:
    app: order-api
    # rollouts-pod-template-hash selector injected by Argo Rollouts
  ports:
    - port: 80
      targetPort: 8080

---
# Canary Service — routes to canary ReplicaSet
apiVersion: v1
kind: Service
metadata:
  name: order-api-canary
  namespace: production
spec:
  selector:
    app: order-api
    # rollouts-pod-template-hash selector injected by Argo Rollouts
  ports:
    - port: 80
      targetPort: 8080
```

### 5.4 Blue/Green Rollout

```yaml
# rollout-blue-green.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: payment-api
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
    spec:
      containers:
        - name: payment-api
          image: ghcr.io/myorg/payment-api:2.0.0
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: "2"
              memory: 1Gi

  strategy:
    blueGreen:
      # Active Service: receives 100% of production traffic
      activeService: payment-api-active

      # Preview Service: points to the new (green) Pods — for testing only
      previewService: payment-api-preview

      # Auto-promotion disabled — require human approval
      autoPromotionEnabled: false

      # Wait 5 minutes after new Pods are ready before allowing promotion
      # Gives time for metrics to stabilise
      autoPromotionSeconds: 0     # 0 = manual promotion only

      # Run analysis on the preview environment before promoting
      prePromotionAnalysis:
        templates:
          - templateName: success-rate-check
        args:
          - name: service-name
            value: payment-api-preview

      # Run analysis for 10 minutes post-promotion (auto-rollback on failure)
      postPromotionAnalysis:
        templates:
          - templateName: success-rate-check
          - templateName: latency-check
        args:
          - name: service-name
            value: payment-api

      # Scale down old ReplicaSet after this delay (keep for quick rollback)
      scaleDownDelaySeconds: 600   # 10 minutes after promotion

---
# Active Service (production traffic)
apiVersion: v1
kind: Service
metadata:
  name: payment-api-active
  namespace: production
spec:
  selector:
    app: payment-api
  ports:
    - port: 80
      targetPort: 8080

---
# Preview Service (testing the green version)
apiVersion: v1
kind: Service
metadata:
  name: payment-api-preview
  namespace: production
spec:
  selector:
    app: payment-api
  ports:
    - port: 80
      targetPort: 8080
```

```bash
# Monitor blue/green rollout
kubectl argo rollouts get rollout payment-api -n production

# Output:
# Name:            payment-api
# Namespace:       production
# Status:          ॥ Paused
# Message:         BlueGreenPause
# Strategy:        BlueGreen
# Active Service:  payment-api-active
# Preview Service: payment-api-preview
#
# REVISION  STATUS   STABLE  CANARY  WEIGHT  INFO
# 3         Healthy  true
# 4         Healthy          true           preview

# Validate the preview environment before promoting
curl https://preview.api.mycompany.com/health/ready
# {"status":"ok","version":"2.0.0"}

# Run regression tests against preview
PAYMENT_API_URL=https://preview.api.mycompany.com npm run test:regression

# Promote green to active (blue/green cutover — instant, no traffic interruption)
kubectl argo rollouts promote payment-api -n production

# Output:
# rollout 'payment-api' promoted

# If something goes wrong — instant rollback to blue
kubectl argo rollouts undo payment-api -n production
```

### 5.5 Traffic Mirroring (Shadow Mode)

```yaml
# Traffic mirroring sends a copy of production traffic to the canary
# without affecting the response seen by users.
# Zero risk: if the canary crashes, users never see it.

apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: search-api
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: search-api
  template:
    metadata:
      labels:
        app: search-api
    spec:
      containers:
        - name: search-api
          image: ghcr.io/myorg/search-api:3.0.0-rc1

  strategy:
    canary:
      stableService: search-api-stable
      canaryService: search-api-canary
      trafficRouting:
        istio:
          virtualService:
            name: search-api-vsvc
            routes:
              - primary

      steps:
        # Step 1: Mirror 100% of production traffic to canary
        # Users still only see stable responses
        - setMirrorRoute:
            name: mirror-route
            percentage: 100
            match:
              - method:
                  exact: GET
                path:
                  prefix: /api/v1/search
        # Step 2: Observe mirrored traffic for 30 minutes
        - pause: {duration: 30m}
        # Step 3: Run analysis on canary performance under real traffic
        - analysis:
            templates:
              - templateName: success-rate-check
              - templateName: latency-check
        # Step 4: If analysis passes, start real traffic shift
        - setMirrorRoute:
            name: mirror-route           # Remove mirror
            percentage: 0
        - setWeight: 10
        - pause: {duration: 10m}
        - setWeight: 50
        - pause: {}
        - setWeight: 100
```

### 5.6 Rollout Observability

```bash
# Real-time rollout dashboard in the terminal
kubectl argo rollouts dashboard -n production
# Opens a terminal UI showing all Rollouts, their status,
# current weights, AnalysisRun results, and event history

# Get detailed rollout information
kubectl argo rollouts get rollout order-api -n production --watch

# View analysis runs
kubectl argo rollouts list analysisruns -n production

# Get analysis run details
kubectl describe analysisrun order-api-abc123 -n production

# Abort a running analysis (and rollback)
kubectl argo rollouts abort order-api -n production

# Retry a failed rollout (if you've fixed the issue)
kubectl argo rollouts retry rollout order-api -n production

# Set a new image directly (triggers a new rollout)
kubectl argo rollouts set image order-api \
  order-api=ghcr.io/myorg/order-api:1.4.4 \
  -n production

# Pause all rollouts in a namespace (e.g. during an incident)
kubectl argo rollouts pause order-api -n production

# Resume
kubectl argo rollouts resume order-api -n production
```

---

## 6. Security Gates — Integrated Pipeline Security

### 6.1 Complete Security Gate Sequence

```
PR opened:
  ├── Gitleaks: no secrets in committed code              [SAST]
  ├── CodeQL: no known vulnerability patterns             [SAST]
  ├── npm audit / pip check: no vulnerable dependencies   [SCA]
  ├── Snyk: deeper dependency analysis                    [SCA]
  ├── Polaris: Helm manifests meet security standards     [Config]
  └── License check: no GPL/AGPL dependencies            [Legal]

On merge to main:
  ├── Trivy image scan: no CRITICAL/HIGH CVEs             [Image]
  ├── Cosign sign: image cryptographically signed         [Supply chain]
  ├── SBOM generated: full software bill of materials     [Compliance]
  └── Attestation: build provenance recorded              [Supply chain]

Pre-production deploy:
  ├── Cosign verify: signature matches expected issuer    [Supply chain]
  ├── Kyverno/OPA: image from allowed registry            [Policy]
  └── Kyverno/OPA: image has valid signature              [Policy]
```

### 6.2 Kyverno Policy — Require Signed Images

```yaml
# Enforce that all production Pods use signed images
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["production"]
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - count: 1
              entries:
                - keyless:
                    subject: "https://github.com/myorg/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
          mutateDigest: true       # Mutate :tag → @sha256:digest for immutability
          verifyDigest: true
          required: true
```

### 6.3 Tekton Pipeline Security Step

```yaml
# A reusable Tekton Task for security scanning
# Used by Jenkins X and standalone Tekton pipelines
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: security-scan
  namespace: tekton-pipelines
spec:
  params:
    - name: image-url
      description: Full image URL to scan
    - name: fail-on-severity
      default: CRITICAL
    - name: output-format
      default: sarif

  results:
    - name: scan-result
      description: "PASS or FAIL"

  steps:
    - name: trivy-scan
      image: aquasec/trivy:0.51.1
      script: |
        #!/usr/bin/env sh
        set -e

        trivy image \
          --exit-code 0 \
          --severity $(params.fail-on-severity) \
          --ignore-unfixed \
          --format $(params.output-format) \
          --output /workspace/trivy-report.sarif \
          $(params.image-url)

        VULN_COUNT=$(trivy image \
          --exit-code 0 \
          --severity $(params.fail-on-severity) \
          --ignore-unfixed \
          --format json \
          $(params.image-url) | \
          jq '[.Results[].Vulnerabilities // [] | .[] | select(.Severity == "CRITICAL")] | length')

        echo "Found ${VULN_COUNT} CRITICAL vulnerabilities"

        if [ "$VULN_COUNT" -gt 0 ]; then
          echo -n "FAIL" > $(results.scan-result.path)
          echo "::error::Trivy found ${VULN_COUNT} CRITICAL vulnerabilities"
          exit 1
        else
          echo -n "PASS" > $(results.scan-result.path)
          echo "No CRITICAL vulnerabilities found"
        fi
```

---

## 7. Step-by-Step Hands-on Walkthrough

### 7.1 End-to-End Pipeline Test

```bash
# Step 1: Fork/clone the sample repository
git clone https://github.com/myorg/order-api
cd order-api

# Step 2: Create a feature branch
git checkout -b feature/add-order-validation

# Step 3: Make a change, commit, push
echo "// Added order validation" >> src/validation.js
git add -A
git commit -m "feat: add order quantity validation"
git push origin feature/add-order-validation

# Step 4: Open a PR — CI pipeline triggers automatically
# Observe in GitHub Actions:
# ✓ lint-and-sast (2m 15s)
# ✓ unit-tests (1m 48s)
# ✓ integration-tests (3m 22s)
# ✓ dependency-audit (1m 05s)

# Step 5: PR is merged to main
# CD pipeline triggers:
# ✓ build-and-push (4m 33s) — image built and pushed to ghcr.io
# ✓ trivy-scan (1m 22s) — no CRITICAL CVEs
# ✓ cosign-sign (15s) — image signed

# Step 6: Staging deploy triggers automatically
# ✓ helm-upgrade-staging (2m 15s)
# ✓ smoke-tests-staging (45s)

# Step 7: Trigger production deploy (manual)
gh workflow run cd-production.yml \
  --field image_tag=$(git rev-parse --short HEAD) \
  --field deployment_strategy=canary
```

### 7.2 Simulate Canary Rollback

```bash
# Verify the rollout has started
kubectl argo rollouts get rollout order-api -n production

# Simulate a bug in the canary (for demonstration)
# In a test environment, artificially inject errors:
kubectl exec -n production deploy/order-api-canary -- \
  sh -c "kill -SIGSTOP 1"  # Pause the process to cause health check failures

# Watch the analysis fail and rollback trigger
kubectl argo rollouts get rollout order-api -n production --watch
# Status: ✖ Degraded
# Message: AnalysisRun "order-api-abc123" failed: "success-rate" assessed Error
#          for metric: Prometheus query returned less than successCondition

# The rollout automatically aborts and rolls back
# Canary weight returns to 0%, all traffic to stable

# View the failed AnalysisRun
kubectl argo rollouts list analysisruns -n production
kubectl describe analysisrun order-api-abc123 -n production
```

---

## 8. Real-World Scenario: Zero-Downtime Migration at FinTech Startup

### The Problem

ClearPay, a payment processing startup, deployed a major refactoring of their payment API that introduced a subtle regression in the retry logic for declined cards. The bug only manifested under production load patterns. Their previous push-based CI/CD (GitHub Actions directly calling `kubectl apply`) meant the entire fleet of 30 Pods was updated before anyone noticed the regression.

**Impact:** 8 minutes of elevated payment decline rates, 2,400 failed transactions, $180,000 in lost revenue.

**Root cause of delayed detection:** No automated analysis on deployments, no traffic splitting, no canary.

### The New Architecture

```
PR merged
    │
    ▼
GitHub Actions CI:
  ├── Unit tests (payment retry logic covered)
  ├── Integration tests (testcontainers + payment simulator)
  ├── Trivy scan (no CVEs)
  └── Push image with git SHA tag: payment-api:abc1234
    │
    ▼
GitOps: Update image tag in Git → Argo CD detects change
    │
    ▼
Argo Rollouts — Canary Strategy:
  Step 1: 5% canary traffic
  Step 2: AnalysisRun — check:
          - payment_success_rate >= 99.5%        ← Key business metric
          - card_decline_rate_change < 1%         ← Detects retry regression
          - p99_latency < 800ms
  Step 3: If analysis passes → 20% → analysis → 50% → manual approval → 100%
  Step 4: If analysis fails → automatic abort → 0% canary → alert fired
```

### The Key AnalysisTemplate (business-metric aware)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: payment-business-metrics
  namespace: production
spec:
  metrics:
    - name: payment-success-rate
      interval: 2m
      count: 3
      successCondition: result[0] >= 0.995
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(payment_transactions_total{
              status="success",
              version="canary"
            }[2m])) /
            sum(rate(payment_transactions_total{
              version="canary"
            }[2m]))

    - name: card-decline-rate-delta
      interval: 2m
      count: 3
      # Canary decline rate must not be more than 1% higher than stable
      successCondition: |
        result[0] <= (
          scalar(
            sum(rate(payment_transactions_total{status="declined",version="stable"}[2m])) /
            sum(rate(payment_transactions_total{version="stable"}[2m]))
          ) + 0.01
        )
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(payment_transactions_total{
              status="declined",
              version="canary"
            }[2m])) /
            sum(rate(payment_transactions_total{
              version="canary"
            }[2m]))
```

### Results

| Incident | Before (push deploy) | After (canary + analysis) |
|---|---|---|
| Same retry regression introduced | 8 min impact, 2,400 failed txns | Caught at 5% canary, 0 impact |
| Deploy-time detection | Post-deploy alert (too late) | AnalysisRun failure at step 2 |
| Rollback time | 12 minutes (redeploy old image) | 45 seconds (automatic abort) |
| Production deployments per week | 2 (fear of change) | 14 (confidence from automation) |
| MTTR for deploy-caused incidents | 18 minutes | 45 seconds |

---

## 9. Common Pitfalls & Best Practices

### Pitfall 1: Treating CI and CD as a Single Pipeline
Many teams build a single pipeline that goes from `git push` to production in one uninterrupted run. This creates a false sense of speed: if the production deploy fails, the entire pipeline re-runs from scratch. **Separate CI (build, test, scan, publish) from CD (deploy, smoke test, promote). CI produces a versioned artifact; CD consumes it. Each stage is independently retryable.**

### Pitfall 2: Long-Lived Feature Branches Destroying CI Value
Continuous Integration means integrating continuously — ideally multiple times per day. A team with 10-day feature branches is not doing CI; they are doing periodic integration. When the branch merges, the conflict resolution and test failures from 10 days of divergence arrive simultaneously. **Enforce short-lived branches (1-3 days max). Use feature flags to merge incomplete features to main without exposing them to users.**

### Pitfall 3: Canary Without Traffic Splitting (Fake Canary)
A common "canary" anti-pattern is updating a single Pod in a Deployment while leaving the rest on the old version. This is not traffic splitting — the load balancer distributes traffic randomly, and the fraction hitting the new Pod depends entirely on Pod count. At 10 replicas, you cannot get 5% traffic to the new Pod; you get 10%. **Use Argo Rollouts with an Istio VirtualService, NGINX Ingress annotations, or AWS ALB weighted target groups for precise traffic weight control.**

### Pitfall 4: AnalysisTemplate Success Conditions That Always Pass
Teams configure AnalysisTemplates with success conditions that are trivially true: `result[0] >= 0.0` (any success rate passes). This provides zero protection — the analysis succeeds even if the canary has a 50% error rate. **Set meaningful thresholds: success rate ≥ 99.5%, P99 latency ≤ 500ms. For critical services, add business metrics like conversion rate or transaction success rate.**

### Pitfall 5: GitHub Actions Storing Cloud Credentials as Secrets
Using long-lived AWS access keys or service account JSON keys as GitHub Actions secrets creates a persistent credential that, if leaked, grants long-term cloud access. **Use OIDC federation (GitHub Actions OIDC → AWS IAM, GCP Workload Identity, Azure Managed Identity). The credential is a short-lived token issued per pipeline run — no rotation required, no long-term exposure.**

### Pitfall 6: Skipping Smoke Tests After Staging Deploy
Teams run exhaustive tests in CI but skip post-deploy smoke tests in staging, assuming "if it passed CI, it will work in staging". Environmental differences (different database versions, different network topology, different secret values) cause failures that only manifest post-deploy. **Always run a lightweight smoke test suite after every environment deploy. Smoke tests should verify the three to five most critical user-facing flows.**

> **CI/CD Production Readiness Checklist**
> - [ ] CI pipeline separates lint/SAST, unit tests, integration tests, and build into distinct jobs
> - [ ] Integration tests run against real dependencies (testcontainers or services blocks)
> - [ ] Code coverage gate enforced (≥80% line coverage blocks merge)
> - [ ] SAST (CodeQL) and secret scanning (Gitleaks) run on every PR
> - [ ] Dependency audit (npm audit / Snyk) runs on every PR
> - [ ] Trivy image scan blocks on CRITICAL/HIGH CVEs before push
> - [ ] Images signed with Cosign using keyless OIDC signing
> - [ ] SBOM generated and attached as OCI attestation
> - [ ] Cloud credentials use OIDC federation — no long-lived keys stored as secrets
> - [ ] Production deploys require manual trigger with image signature verification
> - [ ] Argo Rollouts configured with Prometheus-backed AnalysisTemplates
> - [ ] Canary AnalysisTemplate includes at least one business metric
> - [ ] Blue/green rollouts use post-promotion analysis window
> - [ ] Rollback verified to complete in under 2 minutes
> - [ ] Pipeline failure notifications sent to dedicated Slack channel

---

## 10. Key Takeaways

1. **A Kubernetes CI/CD pipeline is a quality gate system, not just automation.** Each stage is an assertion: tests assert correctness, scans assert security, manifest validation asserts operational compliance, and progressive delivery asserts production behaviour. A pipeline that bypasses any gate is not faster — it is a false economy that defers the failure to a worse time.

2. **GitHub Actions OIDC federation eliminates the biggest CI/CD security risk.** Storing long-lived cloud credentials as GitHub Secrets is a lateral movement risk if the repository is compromised. OIDC-based short-lived tokens are scoped to a specific job, expire within minutes, and require no rotation. Migrate all CI/CD cloud authentication to OIDC.

3. **Jenkins X makes CI/CD a first-class Kubernetes citizen.** By running pipelines as Tekton Pods, using Kaniko for daemon-less builds, and automating GitOps environment promotion, Jenkins X eliminates the impedance mismatch between CI/CD tooling and Kubernetes operations. For teams fully committed to Kubernetes-native workflows, it reduces the number of external tool integrations significantly.

4. **Progressive delivery with Argo Rollouts is the production-grade alternative to RollingUpdate.** RollingUpdate replaces Pods but cannot control traffic distribution or evaluate business metrics. Argo Rollouts canary with Prometheus-backed AnalysisTemplates catches regressions before they affect the full user base — using real production traffic as the test signal.

5. **Traffic mirroring (shadow mode) provides zero-risk production validation.** For high-risk deployments where even 5% canary exposure is unacceptable, traffic mirroring sends a copy of all production traffic to the new version while discarding its responses. The new version is validated under real load with zero user-facing risk.

6. **Image signing with Cosign and policy enforcement with Kyverno closes the supply chain loop.** Signing images in CI and verifying signatures at admission time ensures that no unsigned image — whether from a compromised registry, a misconfigured pipeline, or a direct namespace injection — can run in production. The trust chain is: approved repository → CI pipeline → signed image → Kyverno admission check → running Pod.

---

## 11. Exercises & Labs

**Exercise 1: GitHub Actions CI Pipeline**
Create a GitHub repository with a Node.js application. Build a three-job CI pipeline: (a) lint + CodeQL SAST, (b) unit tests with coverage gate (≥80%), (c) Docker build + Trivy scan (block on CRITICAL). Use job dependencies so jobs run sequentially. Verify: push a commit with a known vulnerability (old `lodash` version) and confirm the Trivy gate blocks the pipeline.

**Exercise 2: OIDC Cloud Authentication**
Replace any stored AWS/GCP/Azure credentials in your GitHub Actions workflow with OIDC federation. For AWS: create an IAM OIDC identity provider for `token.actions.githubusercontent.com`, create a role with a trust policy restricting to your repository, and use `aws-actions/configure-aws-credentials@v4` with `role-to-assume`. Verify: delete the old secret, run the pipeline, and confirm it authenticates successfully.

**Exercise 3: Argo Rollouts Canary with Analysis**
On a test cluster, install Argo Rollouts and convert a Deployment to a Rollout with a 4-step canary: 10% → pause 5m → AnalysisRun (success rate ≥ 99%) → 50% → pause → 100%. Deploy an initial version. Then deploy a new version and observe the canary progressing through steps. Simulate a failure (inject artificial 500 errors), verify the AnalysisRun detects the failure, and observe the automatic rollback to 0% canary weight.

**Exercise 4: Blue/Green with Pre-Promotion Analysis**
Configure a blue/green Rollout with `autoPromotionEnabled: false` and a `prePromotionAnalysis` block. Deploy a new version and verify: (a) the preview Service receives no traffic initially, (b) the AnalysisRun runs against the preview Service, (c) only after the analysis passes can you run `kubectl argo rollouts promote`. Then verify that `kubectl argo rollouts undo` performs an instant rollback.

**Exercise 5: Full Pipeline with GitOps Promotion**
Build a complete end-to-end pipeline: (a) GitHub Actions CI builds and pushes an image on merge to main, (b) CI writes the new image tag to a GitOps repository (update `kustomization.yaml`), (c) Argo CD detects the change and deploys to staging, (d) a smoke test runs against staging, (e) on smoke test success, a PR is automatically opened to update the production overlay, (f) after the PR is merged (manually), Argo CD deploys to production using a Rollout with canary strategy. Time the entire pipeline from `git push` to production canary start.

---

*End of Chapter 12*

**Next → Chapter 13: Managing Microservices Using Istio Service Mesh**
