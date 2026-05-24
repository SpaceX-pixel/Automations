# Chapter 13 — Managing Microservices Using Istio Service Mesh

> *Mastering DevOps in Kubernetes*
> Architecture · Sidecar Injection · Traffic Management · mTLS · Observability · Fault Injection · Multi-Cluster

---

## 1. Introduction & Learning Objectives

A microservices architecture solves the problem of monolithic coupling by decomposing a system into independently deployable services. In doing so, it trades one set of problems for another: how do services discover each other reliably, how do you encrypt inter-service communication without changing application code, how do you control traffic between service versions, and how do you understand the behaviour of a distributed system when a single user request fans out across twelve services?

These are not application problems. They are infrastructure concerns — cross-cutting concerns that every service would need to solve individually if the platform did not solve them once. A **service mesh** is that platform layer. It moves networking logic — load balancing, retries, timeouts, circuit breaking, mTLS, telemetry — out of application code and into a dedicated infrastructure layer, making it consistent, configurable, and observable across every service in the mesh without a single line of application code change.

**Istio** is the most widely deployed, most feature-complete service mesh in the Kubernetes ecosystem. It is a CNCF graduated project originally developed by Google and IBM, and it underpins some of the largest microservices deployments in production. This final chapter covers Istio from first principles — its architecture, its installation, its traffic management API, and its security model — and then applies all of it to real-world scenarios: zero-downtime traffic shifting, chaos engineering with fault injection, mutual TLS enforcement across the entire mesh, and multi-cluster federation for global service availability.

> **Learning Objectives**
> - Explain the Istio architecture: control plane (Istiod) and data plane (Envoy proxies), and how they interact.
> - Install Istio on a production cluster with the correct configuration profile and resource settings.
> - Configure automatic sidecar injection and understand what the Envoy proxy intercepts.
> - Use VirtualService, DestinationRule, and Gateway resources to implement advanced traffic management.
> - Enforce mutual TLS (mTLS) cluster-wide and verify end-to-end encryption between all services.
> - Use Kiali for service mesh topology visualisation and Jaeger/Tempo for distributed tracing.
> - Inject faults (delays, aborts) for chaos engineering to validate service resilience.
> - Configure Istio for multi-cluster federation with failover and load balancing across clusters.
> - Implement circuit breaking, retry policies, and outlier detection to build resilient microservice communication.

---

## 2. Core Concepts

### 2.1 The Service Mesh Problem Space

Before Istio, each microservice was responsible for implementing networking concerns itself — usually via a language-specific library (Netflix Hystrix for circuit breaking, Spring Retry for retries, a custom TLS initialisation routine). This approach has three fundamental problems:

```
Problem 1: Language fragmentation
  Java service uses Hystrix for circuit breaking
  Python service uses tenacity for retries
  Go service uses custom retry logic
  → Inconsistent behaviour, different configuration APIs, different observability

Problem 2: Application-infrastructure coupling
  Retry logic in application code means:
  → Changing retry behaviour requires code changes + tests + deployment
  → Infrastructure operators cannot tune service networking without developer involvement

Problem 3: Invisible inter-service communication
  Service A calls Service B. Service B calls Service C.
  → No visibility into latency at each hop
  → No insight into which requests succeed or fail
  → No way to enforce security policies (encryption, auth) uniformly

Service mesh solution:
  Move ALL networking concerns into a sidecar proxy (Envoy)
  → Consistent behaviour across all languages and runtimes
  → Configuration via Kubernetes CRDs (no code changes)
  → Full telemetry from every network hop, automatically
```

### 2.2 Istio Architecture

Istio is divided into two planes: the **control plane** (Istiod — a single binary that manages configuration) and the **data plane** (Envoy sidecar proxies — one per Pod, handling all inbound and outbound network traffic).

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ISTIO CONTROL PLANE                                                      │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐   │
│  │  Istiod (single binary, replaces Pilot + Mixer + Citadel + Galley)│   │
│  │                                                                    │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │   │
│  │  │  Pilot           │  │  Citadel         │  │  Galley          │   │   │
│  │  │  Service         │  │  Certificate     │  │  Configuration   │   │   │
│  │  │  Discovery       │  │  Authority (CA)  │  │  Validation      │   │   │
│  │  │  Traffic mgmt    │  │  mTLS certs      │  │  CRD webhooks    │   │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘   │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                │ xDS API (gRPC streaming)                                 │
│                │ (Listener, Route, Cluster, Endpoint Discovery Service)   │
└────────────────┼─────────────────────────────────────────────────────────┘
                 │
┌────────────────┼─────────────────────────────────────────────────────────┐
│  DATA PLANE    │                                                          │
│                ▼                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │  Pod: order-api                                                   │    │
│  │                                                                   │    │
│  │  ┌──────────────────────────┐   ┌────────────────────────────┐  │    │
│  │  │  istio-proxy (Envoy)      │   │  order-api container        │  │    │
│  │  │                          │   │                             │  │    │
│  │  │  Inbound: port 15006     │   │  Only sees localhost        │  │    │
│  │  │  Outbound: port 15001    │   │  Envoy is transparent       │  │    │
│  │  │  Admin: port 15000       │   │  to the application         │  │    │
│  │  │  Health: port 15020      │   │                             │  │    │
│  │  │                          │   │  Listens on: 8080           │  │    │
│  │  │  mTLS termination        │   │                             │  │    │
│  │  │  Telemetry collection    │◄──│  Speaks plain HTTP          │  │    │
│  │  │  Retry / timeout         │   │  Envoy handles TLS          │  │    │
│  │  │  Circuit breaking        │   │                             │  │    │
│  │  │  Load balancing          │   │                             │  │    │
│  │  └──────────────────────────┘   └────────────────────────────┘  │    │
│  │     iptables rules redirect all traffic through Envoy             │    │
│  └──────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────┘
```

#### xDS API — How Istiod Configures Envoy

Istiod pushes configuration to Envoy proxies via the xDS (Discovery Service) API — a set of gRPC streaming APIs:

| xDS API | Controls | Corresponds to Istio Resource |
|---|---|---|
| LDS (Listener) | Which ports Envoy listens on | VirtualService, Gateway |
| RDS (Route) | How to route requests by path/header | VirtualService |
| CDS (Cluster) | Upstream service definitions | DestinationRule |
| EDS (Endpoint) | Individual endpoint (Pod) addresses | Service, ServiceEntry |
| SDS (Secret) | TLS certificates | PeerAuthentication, mTLS certs |

#### Traffic Flow Through the Mesh

```
Client Pod (order-api)     Network           Server Pod (payment-api)
──────────────────────     ───────           ───────────────────────
App code calls             encrypted         Envoy receives
payment-api:8080 ─────────▶ mTLS ──────────▶ inbound request
     │                                              │
     │ iptables                                     │ iptables
     ▼ intercept                                    ▼ intercept
Envoy (outbound)                              Envoy (inbound)
     │                                              │
     │ Applies:                                     │ Applies:
     │ ├── Routing rules                            │ ├── mTLS validation
     │ ├── Retry policy                             │ ├── Authz policy
     │ ├── Timeout                                  │ └── Telemetry
     │ ├── Circuit breaker
     │ └── mTLS origination
     │
     └── Strips: x-forwarded-for, injects trace headers
```

---

### 2.3 Sidecar Injection

Istio injects the `istio-proxy` (Envoy) sidecar container into Pods automatically using a **MutatingAdmissionWebhook**. When a Pod is created in a namespace with the injection label, the webhook intercepts the creation request and adds:

1. The `istio-proxy` sidecar container
2. An `istio-init` init container (sets up iptables rules to intercept traffic)
3. The Envoy configuration volume mounts

```yaml
# Enable automatic sidecar injection for a namespace
kubectl label namespace production istio-injection=enabled

# Verify the label
kubectl get namespace production --show-labels
# NAME         STATUS   LABELS
# production   Active   istio-injection=enabled,kubernetes.io/metadata.name=production

# Disable injection for a specific Pod (e.g. database Pods that don't need the mesh)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: production
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"    # Opt out of injection

# Verify sidecar is injected (Pod should show 2 containers: app + istio-proxy)
kubectl get pods -n production
# NAME                         READY   STATUS    RESTARTS
# order-api-7d9b-4xk9p         2/2     Running   0   ← 2 containers: app + proxy
# postgres-0                   1/1     Running   0   ← No sidecar (opted out)

# Inspect the injected proxy
kubectl describe pod order-api-7d9b-4xk9p -n production | grep -A 20 "istio-proxy"

# Check proxy configuration and bootstrap
kubectl exec -n production order-api-7d9b-4xk9p -c istio-proxy -- \
  pilot-agent request GET config_dump | jq '.configs[0]'

# Check proxy synchronisation with Istiod
istioctl proxy-status -n production
# NAME                         CLUSTER  CDS    LDS    EDS    RDS    ISTIOD          VERSION
# order-api-7d9b-4xk9p.prod   Kubernetes SYNCED SYNCED SYNCED SYNCED istiod-abc-123   1.21.0
```

---

### 2.4 Traffic Management — The Core API

Istio's traffic management is expressed through four core resources:

| Resource | Layer | Controls |
|---|---|---|
| `Gateway` | L4-L6 | Entry point for external traffic; configures the ingress gateway |
| `VirtualService` | L7 | How requests are routed to services (by header, path, weight) |
| `DestinationRule` | L4-L6 | How traffic behaves once routed (load balancing, mTLS, circuit breaking) |
| `ServiceEntry` | L3-L4 | Registers external services in the mesh (e.g. external APIs, databases) |

#### Gateway — Ingress Entry Point

```yaml
# Gateway configures the Istio ingress gateway (an Envoy proxy running as a Service)
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ecommerce-gateway
  namespace: production
spec:
  selector:
    istio: ingressgateway       # Targets the default Istio ingress gateway Pod
  servers:
    # HTTP — redirect to HTTPS
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "api.mycompany.com"
        - "*.mycompany.com"
      tls:
        httpsRedirect: true     # 301 redirect all HTTP to HTTPS

    # HTTPS — TLS termination at the gateway
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - "api.mycompany.com"
        - "admin.mycompany.com"
      tls:
        mode: SIMPLE            # TLS termination (MUTUAL for client certs)
        credentialName: ecommerce-tls-cert   # References a Kubernetes Secret with TLS cert
```

#### VirtualService — Advanced Traffic Routing

```yaml
# VirtualService: route requests for api.mycompany.com to order-api or payment-api
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-routing
  namespace: production
spec:
  hosts:
    - "api.mycompany.com"
    - order-api              # Also matches internal mesh traffic to this host
  gateways:
    - ecommerce-gateway      # Applies to external traffic through this gateway
    - mesh                   # Also applies to internal mesh traffic (pod-to-pod)
  http:
    # Route /api/v1/orders to order-api
    - match:
        - uri:
            prefix: /api/v1/orders
      route:
        - destination:
            host: order-api
            port:
              number: 80
      # Timeout for this route
      timeout: 30s
      # Retry policy for this route
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: "gateway-error,connect-failure,retriable-4xx"

    # Route /api/v1/payments to payment-api with canary splitting
    - match:
        - uri:
            prefix: /api/v1/payments
      route:
        - destination:
            host: payment-api
            subset: stable         # 95% to stable
          weight: 95
        - destination:
            host: payment-api
            subset: canary         # 5% to canary
          weight: 5

    # Route based on header (dark launch for internal testing)
    - match:
        - uri:
            prefix: /api/v1/search
          headers:
            x-beta-user:
              exact: "true"
      route:
        - destination:
            host: search-api
            subset: v2-beta

    # Default route — everything else
    - route:
        - destination:
            host: api-gateway
            port:
              number: 80
```

#### DestinationRule — Traffic Behaviour

```yaml
# DestinationRule: defines subsets (for canary) and circuit breaking for payment-api
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: payment-api-dr
  namespace: production
spec:
  host: payment-api
  # TLS mode for connections to this service (auto-detected with mTLS, but explicit is safer)
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL      # Use Istio-managed mTLS certificates

    # Load balancing algorithm for all subsets
    loadBalancer:
      simple: LEAST_CONN      # Least connections (better than round-robin for variable request times)

    # Connection pool settings (circuit breaker at connection level)
    connectionPool:
      tcp:
        maxConnections: 100   # Max simultaneous TCP connections
        connectTimeout: 30ms
      http:
        h2UpgradePolicy: UPGRADE   # Use HTTP/2 if available
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10  # Close connection after 10 requests (avoid hot connections)

    # Outlier detection (circuit breaker at host level)
    outlierDetection:
      consecutive5xxErrors: 5         # Eject after 5 consecutive 5xx errors
      interval: 30s                   # Scan interval
      baseEjectionTime: 30s           # How long to eject the host
      maxEjectionPercent: 50          # Eject at most 50% of hosts simultaneously
      minHealthPercent: 50            # Keep at least 50% healthy hosts in pool

  # Version subsets (referenced by VirtualService)
  subsets:
    - name: stable
      labels:
        version: stable              # Matches Pods with this label
      trafficPolicy:
        loadBalancer:
          simple: ROUND_ROBIN

    - name: canary
      labels:
        version: canary
      trafficPolicy:
        connectionPool:
          http:
            http1MaxPendingRequests: 50   # Lower limit for canary (reduce blast radius)
```

#### ServiceEntry — External Services in the Mesh

```yaml
# Register an external payment gateway so Istio can apply policies to outbound calls
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-payment-gateway
  namespace: production
spec:
  hosts:
    - api.stripe.com
    - api.paypal.com
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  location: MESH_EXTERNAL    # External service, not in the mesh
  resolution: DNS

---
# WorkloadEntry — register a VM workload (legacy system) in the mesh
# Allows a non-Kubernetes workload to participate in the service mesh
apiVersion: networking.istio.io/v1beta1
kind: WorkloadEntry
metadata:
  name: legacy-billing-vm
  namespace: production
spec:
  address: 10.0.10.50          # VM IP address
  ports:
    billing: 8080
  labels:
    app: billing
    version: legacy
  serviceAccount: billing-sa
```

---

### 2.5 Mutual TLS (mTLS)

Mutual TLS is the cornerstone of Istio's zero-trust security model. In standard TLS, only the server presents a certificate (the client verifies the server). In mTLS, both sides present certificates — the server authenticates the client, and the client authenticates the server. This enables service-to-service authentication without any application code changes.

```
Without mTLS:
  order-api ─── plain HTTP ──▶ payment-api
  Anyone on the cluster network can send requests to payment-api

With Istio mTLS:
  order-api ──▶ Envoy proxy ─── mTLS (cert: order-api.production.svc.cluster.local) ───▶
  ──▶ Envoy proxy ─── validates cert ──▶ payment-api
  Only services with valid Istio-issued certificates can communicate
  Certificate identity = SPIFFE URI: spiffe://cluster.local/ns/production/sa/order-api-sa
```

#### Istio Certificate Infrastructure

```
Istiod (Certificate Authority)
    │
    │ Issues short-lived X.509 certificates (24h default)
    │ to each Pod's Envoy proxy via SDS (Secret Discovery Service)
    │
    ├── order-api Pod → cert: spiffe://cluster.local/ns/production/sa/order-api-sa
    ├── payment-api Pod → cert: spiffe://cluster.local/ns/production/sa/payment-api-sa
    └── notification-svc Pod → cert: spiffe://cluster.local/ns/production/sa/notification-sa

Certificate rotation: automatic, transparent to applications
Certificate identity: SPIFFE format (Secure Production Identity Framework for Everyone)
```

```yaml
# PeerAuthentication — enforce mTLS for all services in a namespace
# STRICT mode: reject any plaintext (non-mTLS) connections
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT    # STRICT: mTLS required; PERMISSIVE: accept both; DISABLE: plaintext only

---
# Mesh-wide mTLS enforcement (applies to all namespaces)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: mesh-wide-mtls
  namespace: istio-system      # istio-system namespace = mesh-wide scope
spec:
  mtls:
    mode: STRICT

---
# Port-level exception: allow plaintext on metrics port (Prometheus scraping)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: order-api-mtls
  namespace: production
spec:
  selector:
    matchLabels:
      app: order-api
  mtls:
    mode: STRICT             # Default for all ports
  portLevelMtls:
    9090:
      mode: PERMISSIVE       # Allow plaintext on metrics port (Prometheus)
    15020:
      mode: PERMISSIVE       # Istio health check port
```

#### AuthorizationPolicy — Service-Level Access Control

```yaml
# Deny all traffic by default (zero-trust baseline)
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}   # Empty spec = deny everything

---
# Allow order-api to call payment-api on specific paths only
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-order-to-payment
  namespace: production
spec:
  selector:
    matchLabels:
      app: payment-api
  action: ALLOW
  rules:
    - from:
        - source:
            # Only allow traffic from the order-api ServiceAccount
            principals:
              - "cluster.local/ns/production/sa/order-api-sa"
      to:
        - operation:
            methods: ["POST"]
            paths: ["/api/v1/payments", "/api/v1/refunds"]
      when:
        - key: request.headers[x-request-id]
          notValues: [""]    # Require a request ID (tracing)

---
# Allow Prometheus to scrape metrics from all services
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: production
spec:
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/monitoring/sa/prometheus"
      to:
        - operation:
            methods: ["GET"]
            paths: ["/metrics", "/healthz", "/ready"]

---
# JWT authentication: require valid JWT for external API calls
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-validation
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  jwtRules:
    - issuer: "https://auth.mycompany.com"
      jwksUri: "https://auth.mycompany.com/.well-known/jwks.json"
      audiences:
        - "api.mycompany.com"
      forwardOriginalToken: true

---
# Require JWT for all requests except health checks
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  action: ALLOW
  rules:
    - from:
        - source:
            requestPrincipals: ["*"]   # Any valid JWT
      to:
        - operation:
            notPaths: ["/health/*"]    # Except health endpoints
```

---

### 2.6 Resilience Patterns

#### Retry Policy

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: inventory-api-vs
  namespace: production
spec:
  hosts:
    - inventory-api
  http:
    - route:
        - destination:
            host: inventory-api
      # Retry configuration
      retries:
        attempts: 3                        # Retry up to 3 times
        perTryTimeout: 5s                  # Each attempt has 5s timeout
        retryOn: >-
          gateway-error,
          connect-failure,
          retriable-4xx,
          reset,
          refused-stream
        retryRemoteLocalities: true        # Retry on a different Pod

      # Overall timeout (must be > attempts × perTryTimeout)
      timeout: 20s
```

#### Circuit Breaker

```yaml
# DestinationRule circuit breaker for the inventory API
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: inventory-api-dr
  namespace: production
spec:
  host: inventory-api
  trafficPolicy:
    outlierDetection:
      # Eject a host from the load balancing pool when:
      consecutive5xxErrors: 3          # 3 consecutive 5xx responses
      consecutiveGatewayErrors: 3      # OR 3 consecutive gateway errors
      interval: 10s                    # Evaluate every 10s
      baseEjectionTime: 30s            # Eject for minimum 30s
      maxEjectionPercent: 100          # Allow ejecting all hosts if all are unhealthy
      # (With 100%, the circuit breaker "opens" completely)
      splitExternalLocalOriginErrors: true
      consecutiveLocalOriginFailures: 3
```

#### Fault Injection — Chaos Engineering

```yaml
# Inject a 5-second delay into 10% of requests to test timeout handling
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: recommendation-api-vs
  namespace: production
spec:
  hosts:
    - recommendation-api
  http:
    - fault:
        delay:
          percentage:
            value: 10.0          # Affect 10% of requests
          fixedDelay: 5s         # Inject 5-second delay

        # Also inject HTTP 503 errors for 2% of requests
        abort:
          percentage:
            value: 2.0
          httpStatus: 503

      route:
        - destination:
            host: recommendation-api

---
# Fault injection scoped to a specific user (header-based)
# Useful for targeted chaos testing without affecting real users
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: cart-api-vs
  namespace: production
spec:
  hosts:
    - cart-api
  http:
    # Inject fault only for requests with x-chaos-user header
    - match:
        - headers:
            x-chaos-user:
              exact: "test-user-chaos"
      fault:
        abort:
          httpStatus: 500
          percentage:
            value: 100.0         # 100% fault for this user
      route:
        - destination:
            host: cart-api

    # Normal traffic for all other users
    - route:
        - destination:
            host: cart-api
```

---

### 2.7 Observability — Kiali and Jaeger

#### Kiali — Service Mesh Topology Visualisation

Kiali provides a real-time graph of the service mesh — which services are communicating with which, the traffic rates and error rates on each connection, and the health of each service. It is the observability control plane for Istio.

```bash
# Install Kiali via Helm
helm repo add kiali https://kiali.org/helm-charts
helm repo update

helm install kiali-server kiali/kiali-server \
  --namespace istio-system \
  --version 1.86.0 \
  --set auth.strategy=anonymous \   # Use 'openid' in production
  --set external_services.prometheus.url=http://kube-prometheus-stack-prometheus.monitoring:9090 \
  --set external_services.tracing.in_cluster_url=http://tracing.istio-system:16685 \
  --set external_services.grafana.in_cluster_url=http://kube-prometheus-stack-grafana.monitoring:80

# Port-forward to access Kiali UI
kubectl port-forward svc/kiali -n istio-system 20001:20001
# Open: http://localhost:20001/kiali
```

```yaml
# KialiConfig — production Kiali configuration
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali
  namespace: istio-system
spec:
  auth:
    strategy: openid
    openid:
      client_id: kiali
      issuer_uri: https://auth.mycompany.com
      username_claim: email
      scopes: [openid, profile, email]

  external_services:
    prometheus:
      url: http://kube-prometheus-stack-prometheus.monitoring:9090
    grafana:
      enabled: true
      in_cluster_url: http://kube-prometheus-stack-grafana.monitoring:80
      url: https://grafana.mycompany.com
    tracing:
      enabled: true
      in_cluster_url: http://tempo.monitoring:16685
      use_grpc: true

  server:
    metrics_enabled: true
    metrics_port: 9090

  deployment:
    accessible_namespaces: ["production", "staging", "development"]
    replicas: 2                    # HA Kiali
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
```

#### Istio Telemetry — Metrics, Tracing, Access Logs

```yaml
# Telemetry resource — configure metrics and tracing for the mesh
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-telemetry
  namespace: istio-system      # Mesh-wide configuration
spec:
  # Distributed tracing configuration
  tracing:
    - providers:
        - name: tempo           # Send traces to Tempo via OpenTelemetry
      randomSamplingPercentage: 1.0   # 1% sampling (adjust per traffic volume)
      disableSpanReporting: false
      customTags:
        cluster:
          literal:
            value: "production-eks"
        env:
          environment:
            name: APP_ENV
            defaultValue: "production"

  # Access log configuration
  accessLogging:
    - providers:
        - name: envoy
      disabled: false

  # Prometheus metrics
  metrics:
    - providers:
        - name: prometheus
      overrides:
        - match:
            metric: REQUEST_COUNT
            mode: CLIENT_AND_SERVER
          tagOverrides:
            # Remove high-cardinality labels that can cause prometheus memory issues
            destination_principal:
              operation: REMOVE
            source_principal:
              operation: REMOVE

---
# EnvoyFilter — customise Envoy configuration at a low level
# Use sparingly — requires deep Envoy knowledge
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: compress-response
  namespace: production
spec:
  workloadSelector:
    labels:
      app: order-api
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: SIDECAR_INBOUND
        listener:
          portNumber: 8080
          filterChain:
            filter:
              name: "envoy.filters.network.http_connection_manager"
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.compressor
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.compressor.v3.Compressor
            response_direction_config:
              common_config:
                min_content_length: 1024
                content_type:
                  - application/json
              disable_on_etag_header: true
            compressor_library:
              name: gzip
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.compression.gzip.compressor.v3.Gzip
```

---

### 2.8 Multi-Cluster Service Mesh

Istio supports multi-cluster federation — extending the service mesh across multiple Kubernetes clusters. This enables cross-cluster service discovery, failover, and load balancing.

```
Multi-Cluster Topology Options:

Primary-Remote (single control plane):
  Cluster 1 (primary):   Istiod control plane + workloads
  Cluster 2 (remote):    Only workloads (no Istiod)
  Cluster 1 Istiod manages both clusters
  Use case: Simple setup, single team managing multiple clusters

Multi-Primary (multiple control planes):
  Cluster 1 (primary):   Istiod + workloads
  Cluster 2 (primary):   Istiod + workloads
  Both Istiods are aware of each other's services
  Use case: HA, multi-region, independent clusters with shared mesh

External control plane:
  Control plane cluster:  Only Istiod (no workloads)
  Workload clusters:      Only workloads
  Use case: Centralised mesh management across many clusters
```

---

## 3. Istio Installation

### 3.1 Installation with istioctl

```bash
# Install istioctl
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.21.0 sh -
export PATH=$PWD/istio-1.21.0/bin:$PATH

# Verify compatibility
istioctl x precheck

# Install with the production profile (no demo add-ons)
# The 'default' profile enables: istiod + ingress gateway
istioctl install \
  --set profile=default \
  --set values.pilot.resources.requests.cpu=500m \
  --set values.pilot.resources.requests.memory=2048Mi \
  --set values.pilot.resources.limits.cpu=2000m \
  --set values.pilot.resources.limits.memory=4096Mi \
  --set values.pilot.replicaCount=2 \
  --set values.global.proxy.resources.requests.cpu=100m \
  --set values.global.proxy.resources.requests.memory=128Mi \
  --set values.global.proxy.resources.limits.cpu=500m \
  --set values.global.proxy.resources.limits.memory=256Mi \
  -y

# Verify installation
istioctl verify-install
kubectl get pods -n istio-system
# NAME                                     READY   STATUS    RESTARTS
# istio-ingressgateway-5d4f8b9c7-xk9p2    1/1     Running   0
# istio-ingressgateway-5d4f8b9c7-8vr2q    1/1     Running   0
# istiod-6d4f8b9c7-m9t7n                  1/1     Running   0
# istiod-6d4f8b9c7-4xk9p                  1/1     Running   0
```

### 3.2 Production IstioOperator Manifest

```yaml
# istio-production.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: production-istio
  namespace: istio-system
spec:
  profile: default
  hub: docker.io/istio
  tag: 1.21.0

  meshConfig:
    # Enable access logging to stdout (collected by Promtail/Fluentd)
    accessLogFile: /dev/stdout
    accessLogFormat: |
      {"start_time":"%START_TIME%","method":"%REQ(:METHOD)%","path":"%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
       "protocol":"%PROTOCOL%","response_code":"%RESPONSE_CODE%","duration_ms":"%DURATION%",
       "upstream_host":"%UPSTREAM_HOST%","x_forwarded_for":"%REQ(X-FORWARDED-FOR)%",
       "trace_id":"%REQ(X-B3-TRACEID)%","service":"%REQ(:AUTHORITY)%"}

    # Default proxy configuration
    defaultConfig:
      # Zipkin/Jaeger tracing endpoint
      tracing:
        sampling: 1.0          # 1% (increase for debugging, reduce for high-traffic prod)
        zipkin:
          address: tempo.monitoring:9411

      # Proxy access log format
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"    # DNS-based service discovery (improves ServiceEntry reliability)
        ISTIO_META_PROXY_XDS_VIA_AGENT: "true"

    # mTLS mode for the mesh
    enableAutoMtls: true

    # Outbound traffic policy (REGISTRY_ONLY = block unknown external hosts)
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY     # Only allow traffic to registered ServiceEntries
      # Use ALLOW_ANY during migration; REGISTRY_ONLY for strict zero-trust

    # Enable extensions
    extensionProviders:
      - name: tempo
        opentelemetry:
          service: opentelemetry-collector.monitoring
          port: 4317

  components:
    # Istiod (control plane)
    pilot:
      k8s:
        replicaCount: 2
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        hpaSpec:
          maxReplicas: 5
          minReplicas: 2
          metrics:
            - type: Resource
              resource:
                name: cpu
                target:
                  type: Utilization
                  averageUtilization: 80
        podDisruptionBudget:
          minAvailable: 1

    # Ingress gateway
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          replicaCount: 2
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 2000m
              memory: 1Gi
          hpaSpec:
            maxReplicas: 10
            minReplicas: 2
          service:
            type: LoadBalancer
            ports:
              - port: 15021
                targetPort: 15021
                name: status-port
              - port: 80
                targetPort: 8080
                name: http2
              - port: 443
                targetPort: 8443
                name: https

    # Egress gateway (optional — for controlled external access)
    egressGateways:
      - name: istio-egressgateway
        enabled: true
        k8s:
          replicaCount: 1
          resources:
            requests:
              cpu: 100m
              memory: 128Mi

  values:
    # Global sidecar proxy resource configuration
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        # Holddown period for graceful termination
        lifecycle:
          postStart:
            exec:
              command:
                - pilot-agent
                - wait
          preStop:
            exec:
              command:
                - /bin/sh
                - -c
                - sleep 5
      # Trust domain for SPIFFE certificates
      trustDomain: cluster.local
```

```bash
# Apply the production configuration
istioctl install -f istio-production.yaml -y

# Upgrade Istio to a new version (canary upgrade)
# Install new control plane alongside old
istioctl install \
  --set profile=default \
  --set revision=1-21-1    # Install as a new revision

# Migrate namespaces to new revision gradually
kubectl label namespace staging istio.io/rev=1-21-1 --overwrite
kubectl rollout restart deployment -n staging  # Restart to pick up new sidecar

# Verify all proxies on new version in staging
istioctl proxy-status -n staging | grep "1.21.1"

# Complete migration to production namespace
kubectl label namespace production istio.io/rev=1-21-1 --overwrite
kubectl rollout restart deployment -n production

# Remove old revision after migration
istioctl uninstall --revision=1-21-0 -y
```

---

## 4. Full Application Configuration

### 4.1 Complete E-Commerce Service Mesh

```yaml
# Complete Istio configuration for an e-commerce platform
# Services: api-gateway, order-api, payment-api, inventory-api, notification-svc

---
# ── Gateway ─────────────────────────────────────────────────────────
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ecommerce-gw
  namespace: production
spec:
  selector:
    istio: ingressgateway
  servers:
    - port: {number: 80, name: http, protocol: HTTP}
      hosts: ["api.mycompany.com"]
      tls:
        httpsRedirect: true
    - port: {number: 443, name: https, protocol: HTTPS}
      hosts: ["api.mycompany.com"]
      tls:
        mode: SIMPLE
        credentialName: api-tls-cert

---
# ── VirtualService: api-gateway (main entry point) ─────────────────
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-gateway-vs
  namespace: production
spec:
  hosts:
    - "api.mycompany.com"
    - api-gateway
  gateways:
    - ecommerce-gw
    - mesh
  http:
    - match:
        - uri: {prefix: /api/v1/orders}
      route:
        - destination: {host: order-api, port: {number: 80}}
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: "5xx,reset,connect-failure"

    - match:
        - uri: {prefix: /api/v1/payments}
      route:
        - destination:
            host: payment-api
            subset: stable
          weight: 100

    - match:
        - uri: {prefix: /api/v1/inventory}
      route:
        - destination: {host: inventory-api, port: {number: 80}}
      timeout: 10s

    - route:
        - destination: {host: api-gateway, port: {number: 80}}

---
# ── DestinationRule: order-api ──────────────────────────────────────
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: order-api-dr
  namespace: production
spec:
  host: order-api
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp: {maxConnections: 100}
      http: {http2MaxRequests: 500, maxRequestsPerConnection: 5}
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50

---
# ── DestinationRule: payment-api with subsets ───────────────────────
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: payment-api-dr
  namespace: production
spec:
  host: payment-api
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp: {maxConnections: 50, connectTimeout: 30ms}
      http: {http2MaxRequests: 200}
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 60s
      maxEjectionPercent: 100   # Open circuit completely on failures
  subsets:
    - name: stable
      labels: {version: stable}
    - name: canary
      labels: {version: canary}
      trafficPolicy:
        connectionPool:
          http: {http2MaxRequests: 50}

---
# ── ServiceEntry: external Stripe API ──────────────────────────────
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: stripe-api
  namespace: production
spec:
  hosts: [api.stripe.com]
  ports:
    - {number: 443, name: https, protocol: HTTPS}
  location: MESH_EXTERNAL
  resolution: DNS

---
# Egress VirtualService: apply retry and timeout to Stripe calls
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: stripe-egress-vs
  namespace: production
spec:
  hosts: [api.stripe.com]
  http:
    - route:
        - destination: {host: api.stripe.com, port: {number: 443}}
      timeout: 30s
      retries:
        attempts: 2
        perTryTimeout: 15s
        retryOn: "5xx,reset"

---
# ── mTLS Enforcement ────────────────────────────────────────────────
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT

---
# ── AuthorizationPolicies ───────────────────────────────────────────
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec: {}

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-ingress-to-api-gateway
  namespace: production
spec:
  selector:
    matchLabels:
      app: api-gateway
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-api-gateway-to-services
  namespace: production
spec:
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/production/sa/api-gateway-sa"]
      to:
        - operation:
            methods: ["GET", "POST", "PUT", "DELETE"]
```

---

## 5. Step-by-Step Hands-on Walkthrough

### 5.1 Deploy and Verify the Full Stack

```bash
# Step 1: Install Istio and enable injection
istioctl install -f istio-production.yaml -y
kubectl label namespace production istio-injection=enabled

# Step 2: Deploy the application
kubectl apply -k k8s/overlays/production

# Verify sidecars are injected (all pods should show 2/2 READY)
kubectl get pods -n production
# NAME                           READY   STATUS
# api-gateway-abc-123            2/2     Running
# order-api-def-456              2/2     Running
# payment-api-ghi-789            2/2     Running

# Step 3: Apply Istio configuration
kubectl apply -f istio/gateway.yaml
kubectl apply -f istio/virtualservices.yaml
kubectl apply -f istio/destinationrules.yaml
kubectl apply -f istio/security.yaml

# Step 4: Verify proxy status
istioctl proxy-status -n production
# All proxies should show SYNCED for CDS, LDS, EDS, RDS

# Step 5: Get the ingress gateway external IP
kubectl get svc istio-ingressgateway -n istio-system
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Step 6: Test the application
curl -H "Host: api.mycompany.com" http://$GATEWAY_IP/api/v1/orders
```

### 5.2 Verify mTLS is Enforced

```bash
# Check mTLS status for all services
istioctl authn tls-check -n production

# Output:
# HOST:PORT                                STATUS  SERVER    CLIENT
# api-gateway.production:80               OK      mTLS      mTLS
# order-api.production:80                 OK      mTLS      mTLS
# payment-api.production:80               OK      mTLS      mTLS

# Verify a specific connection
istioctl authn tls-check \
  order-api-def-456.production \
  payment-api.production

# Try to connect without mTLS (should fail in STRICT mode)
kubectl run plaintext-test \
  --image=curlimages/curl \
  --restart=Never \
  --annotations="sidecar.istio.io/inject=false" \
  -n production \
  -- curl -v http://payment-api:80/health
# curl: (35) OpenSSL SSL_connect: Connection reset by peer
# ← Connection refused without valid mTLS cert

# Test connection FROM a properly meshed Pod (should work)
kubectl exec -n production deploy/order-api \
  -- curl -s http://payment-api/health
# {"status":"ok"} ← Works because Envoy handles mTLS automatically

# Inspect the certificate Envoy is using
kubectl exec -n production order-api-def-456 \
  -c istio-proxy \
  -- openssl s_client \
    -connect payment-api:80 \
    -showcerts 2>/dev/null | \
  openssl x509 -noout -subject -issuer
# subject=URI:spiffe://cluster.local/ns/production/sa/order-api-sa
# issuer=O=cluster.local
```

### 5.3 Traffic Shifting — Canary Deployment

```bash
# Initial state: 100% traffic to stable
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: payment-api-vs
  namespace: production
spec:
  hosts:
    - payment-api
  http:
    - route:
        - destination:
            host: payment-api
            subset: stable
          weight: 100
        - destination:
            host: payment-api
            subset: canary
          weight: 0
EOF

# Deploy canary version (add version: canary label to some pods)
kubectl set image deployment/payment-api-canary \
  payment-api=ghcr.io/myorg/payment-api:2.1.0-rc1 \
  -n production

# Shift 5% of traffic to canary
kubectl patch virtualservice payment-api-vs -n production \
  --type=merge \
  -p '{"spec":{"http":[{"route":[{"destination":{"host":"payment-api","subset":"stable"},"weight":95},{"destination":{"host":"payment-api","subset":"canary"},"weight":5}]}]}}'

# Monitor error rates in real time
watch -n 5 "kubectl exec -n production deploy/api-gateway \
  -- curl -s http://payment-api/metrics | \
  grep 'http_requests_total'"

# Check Kiali for the traffic split visualisation
kubectl port-forward svc/kiali -n istio-system 20001:20001 &
open http://localhost:20001/kiali/console/graph/namespaces/

# Progressively shift more traffic
for WEIGHT in 10 20 50 100; do
  STABLE=$((100 - WEIGHT))
  kubectl patch virtualservice payment-api-vs -n production \
    --type=json \
    -p "[
      {\"op\":\"replace\",\"path\":\"/spec/http/0/route/0/weight\",\"value\":$STABLE},
      {\"op\":\"replace\",\"path\":\"/spec/http/0/route/1/weight\",\"value\":$WEIGHT}
    ]"
  echo "Shifted to $WEIGHT% canary"
  sleep 300    # Wait 5 minutes between steps
done
```

### 5.4 Chaos Engineering — Fault Injection

```bash
# Experiment 1: Inject a 3-second delay into 50% of requests to inventory-api
# Goal: Verify that order-api handles inventory timeouts gracefully
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: inventory-chaos-vs
  namespace: production
spec:
  hosts:
    - inventory-api
  http:
    - fault:
        delay:
          percentage:
            value: 50.0
          fixedDelay: 3s
      route:
        - destination:
            host: inventory-api
EOF

# Run requests and observe the impact
kubectl run chaos-test \
  --image=curlimages/curl \
  --restart=Never \
  -n production \
  -- sh -c "
    for i in \$(seq 1 20); do
      START=\$(date +%s%3N)
      STATUS=\$(curl -s -o /dev/null -w '%{http_code}' http://order-api/api/v1/orders)
      END=\$(date +%s%3N)
      echo \"Request \$i: status=\$STATUS time=\$((END-START))ms\"
    done
  "

# Observe in Grafana: P99 latency should spike for inventory calls
# Observe in Kiali: connection health between order-api and inventory-api degrades
# Verify: order-api should timeout gracefully (not cascade the failure)

# Clean up fault injection
kubectl delete virtualservice inventory-chaos-vs -n production

# Experiment 2: Inject 503 errors to test circuit breaker
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: notification-chaos-vs
  namespace: production
spec:
  hosts:
    - notification-svc
  http:
    - fault:
        abort:
          percentage:
            value: 80.0
          httpStatus: 503
      route:
        - destination:
            host: notification-svc
EOF

# Watch the circuit breaker open in the DestinationRule outlier detection
# After 3 consecutive 503s, notification-svc should be ejected from the pool
# Order-api should continue working (notifications are async)

kubectl exec -n production deploy/order-api \
  -c istio-proxy \
  -- pilot-agent request GET stats | \
  grep "outlier_detection.ejections_active"
# cluster.outbound|80||notification-svc.production.svc.cluster.local.outlier_detection.ejections_active: 1

kubectl delete virtualservice notification-chaos-vs -n production
```

---

## 6. Multi-Cluster Service Mesh

### 6.1 Multi-Primary Multi-Network Setup

```bash
# Scenario: Two EKS clusters (us-east-1, eu-west-1)
# Each has its own Istiod control plane
# Services can call each other across clusters transparently

# ── Cluster 1 (us-east-1) setup ──────────────────────────────────────
# Set context for cluster 1
kubectl config use-context eks-us-east-1

# Install Istio as primary cluster
cat > cluster1.yaml << 'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1-us-east-1
      network: network1
EOF

istioctl install -f cluster1.yaml --context eks-us-east-1 -y

# Install east-west gateway (handles cross-cluster traffic)
istioctl install \
  --set profile=empty \
  --set values.gateways.istio-ingressgateway.name=istio-eastwestgateway \
  --set values.global.meshID=mesh1 \
  --set values.global.multiCluster.clusterName=cluster1-us-east-1 \
  --set values.global.network=network1 \
  --context eks-us-east-1 \
  -y

# Expose all services via the east-west gateway
kubectl apply -n istio-system \
  -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/multicluster/expose-services.yaml \
  --context eks-us-east-1

# ── Cluster 2 (eu-west-1) setup ──────────────────────────────────────
kubectl config use-context eks-eu-west-1

cat > cluster2.yaml << 'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster2-eu-west-1
      network: network2
EOF

istioctl install -f cluster2.yaml --context eks-eu-west-1 -y

istioctl install \
  --set profile=empty \
  --set values.gateways.istio-ingressgateway.name=istio-eastwestgateway \
  --set values.global.meshID=mesh1 \
  --set values.global.multiCluster.clusterName=cluster2-eu-west-1 \
  --set values.global.network=network2 \
  --context eks-eu-west-1 \
  -y

kubectl apply -n istio-system \
  -f https://raw.githubusercontent.com/istio/istio/release-1.21/samples/multicluster/expose-services.yaml \
  --context eks-eu-west-1

# ── Enable endpoint discovery between clusters ──────────────────────
# Create remote secrets (allows each Istiod to discover endpoints in the other cluster)
istioctl create-remote-secret \
  --context eks-us-east-1 \
  --name cluster1-us-east-1 | \
  kubectl apply -f - --context eks-eu-west-1

istioctl create-remote-secret \
  --context eks-eu-west-1 \
  --name cluster2-eu-west-1 | \
  kubectl apply -f - --context eks-us-east-1
```

### 6.2 Cross-Cluster Failover

```yaml
# DestinationRule with locality-weighted load balancing and failover
# Primary: serve from local cluster; Failover: route to remote cluster
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: order-api-multicluster
  namespace: production
spec:
  host: order-api
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
    loadBalancer:
      # Distribute load based on cluster locality
      localityLbSetting:
        enabled: true
        # Distribute within region first, fail over to other region
        distribute:
          - from: "us-east-1/*"
            to:
              "us-east-1/*": 90        # 90% to local us-east-1 instances
              "eu-west-1/*": 10        # 10% to eu-west-1 (warm standby)
          - from: "eu-west-1/*"
            to:
              "eu-west-1/*": 90
              "us-east-1/*": 10
        failover:
          - from: us-east-1            # If us-east-1 is unavailable
            to: eu-west-1             # Fail over to eu-west-1
          - from: eu-west-1
            to: us-east-1
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s

---
# VirtualService with cross-cluster header injection for observability
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-api-multicluster-vs
  namespace: production
spec:
  hosts:
    - order-api
  http:
    - route:
        - destination:
            host: order-api
      headers:
        request:
          set:
            x-served-by-cluster: "{{cluster_name}}"
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: "5xx,reset,connect-failure"
```

---

## 7. Observability Deep Dive

### 7.1 Istio Metrics — The Standard Dashboard

```bash
# Istio automatically generates metrics for every proxied connection
# Key metrics exposed by the Envoy proxy:

# Request rate per service
istio_requests_total{reporter="destination", destination_service_name="order-api"}

# P99 latency
histogram_quantile(0.99,
  sum(irate(istio_request_duration_milliseconds_bucket{
    destination_service_name="order-api",
    response_code!~"5.."
  }[1m])) by (le)
)

# Error rate per service pair
sum(irate(istio_requests_total{
  reporter="source",
  destination_service_name="payment-api",
  response_code=~"5.."
}[5m])) /
sum(irate(istio_requests_total{
  reporter="source",
  destination_service_name="payment-api"
}[5m]))

# Active TCP connections
sum(istio_tcp_connections_opened_total) by (destination_service_name)

# Monitor mTLS enforcement
sum(istio_requests_total{
  connection_security_policy="mutual_tls"
}) /
sum(istio_requests_total) * 100
# Should be 100% when STRICT mTLS is enforced
```

### 7.2 Kiali Service Graph Queries

```bash
# Port-forward Kiali
kubectl port-forward svc/kiali -n istio-system 20001:20001

# Kiali REST API for programmatic access
# Get service topology
curl -s "http://localhost:20001/kiali/api/namespaces/production/graph" \
  -H "Content-Type: application/json" | \
  jq '.elements.nodes[] | select(.data.nodeType=="service") | .data.service'

# Check health of all services
curl -s "http://localhost:20001/kiali/api/namespaces/production/health" | \
  jq '.workloadStatuses | to_entries[] | {service: .key, health: .value}'
```

### 7.3 Debugging with istioctl

```bash
# Analyse the mesh configuration for issues
istioctl analyze -n production
# Checking 12 objects across 1 namespaces and cluster scoped resources...
# ✔ No validation issues found when analyzing namespace: production.

# Trace a specific request through the mesh
istioctl x injected-envoy-config \
  order-api-def-456.production \
  -o json | \
  jq '.dynamicActiveListeners[] | .listener.address'

# Check what routes Envoy knows about
istioctl proxy-config routes order-api-def-456.production

# Check what clusters (upstream services) are configured
istioctl proxy-config clusters order-api-def-456.production

# Check current endpoints for the payment-api cluster
istioctl proxy-config endpoints order-api-def-456.production \
  --cluster "outbound|80||payment-api.production.svc.cluster.local"

# Log level adjustment for debugging (temporary)
istioctl proxy-config log order-api-def-456.production \
  --level debug

# Restore normal log level
istioctl proxy-config log order-api-def-456.production \
  --level warning
```

---

## 8. Real-World Scenario: Global E-Commerce Platform with Istio

### The Problem

MegaShop operates a global e-commerce platform with 200+ microservices across three AWS regions. Their architecture evolved organically over 5 years, resulting in:

- **No service-to-service encryption**: an internal security audit found 47 service pairs communicating over plain HTTP, including the payment service calling the fraud detection API
- **Inconsistent resilience**: 12 services had their own retry logic implemented differently; 6 services had no timeout configuration at all, causing cascading failures during Black Friday
- **Invisible service graph**: 23 engineers were asked to map service dependencies; they produced 23 different diagrams
- **Fragile deployments**: new service versions were deployed as Deployment updates; a bad payment-api deploy in November brought down checkout for 14 minutes

### The Istio Migration Path

**Phase 1 (Weeks 1-2): Install and observe, inject nothing**

```bash
# Install Istio in ambient mode observation first
# (ambient mode = no sidecars, just L4 monitoring)
istioctl install --set profile=ambient -y

# Instrument namespace for L4 observation
kubectl label namespace production istio.io/dataplane-mode=ambient

# Observe traffic patterns for 2 weeks before any policy changes
# This produced the "authoritative" service dependency map MegaShop never had
```

**Phase 2 (Weeks 3-4): Enable sidecar injection, PERMISSIVE mTLS**

```bash
kubectl label namespace production istio-injection=enabled
kubectl rollout restart deployment -n production

# Apply PERMISSIVE mTLS first (accepts both plain and mTLS)
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

**Phase 3 (Week 5): Validate, then enforce STRICT mTLS**

```bash
# Verify 100% of traffic is using mTLS (via Kiali metrics)
# Before switching to STRICT
MTLS_PCT=$(kubectl exec -n monitoring deploy/prometheus \
  -- promtool query instant \
  'sum(istio_requests_total{connection_security_policy="mutual_tls",reporter="destination",namespace="production"}) / sum(istio_requests_total{reporter="destination",namespace="production"}) * 100' | \
  jq -r '.[0].value[1]')

echo "mTLS percentage: $MTLS_PCT%"
# Should be 100.0% before proceeding

kubectl patch peerauthentication default -n production \
  --type=merge \
  -p '{"spec":{"mtls":{"mode":"STRICT"}}}'
```

**Phase 4 (Week 6): Progressive delivery with Argo Rollouts + Istio**

All Deployments converted to Rollouts with Istio VirtualService traffic splitting (Chapter 12 canary pattern). The Black Friday deploy that would have taken 14 minutes to roll back now takes 45 seconds.

### Results

| Problem | Before Istio | After Istio |
|---|---|---|
| Service-to-service encryption | 0% (plain HTTP everywhere) | 100% mTLS (STRICT) |
| Consistency of retry logic | 12 different implementations | 1 (VirtualService, uniform) |
| Services with no timeout | 6 | 0 |
| Time to generate service dependency map | 1 week, 23 different answers | 5 seconds (Kiali) |
| Deployment rollback time (bad deploy) | 14 minutes | 45 seconds |
| Black Friday cascading failure incidents | 3 in previous year | 0 |
| Certificate rotation operational burden | Manual, quarterly | Automatic, daily |

---

## 9. Common Pitfalls & Best Practices

### Pitfall 1: Starting with STRICT mTLS on Day One
Enabling STRICT mTLS immediately means any service without a sidecar (DaemonSets, Jobs, external services) immediately loses connectivity. The migration path must always be PERMISSIVE first, validate 100% mTLS coverage via metrics, then switch to STRICT. Rushing to STRICT breaks production.

### Pitfall 2: No `outboundTrafficPolicy: REGISTRY_ONLY`
By default, Istio allows Pods to call any external address not in the mesh (`ALLOW_ANY`). This means a compromised container can exfiltrate data to any IP. Setting `outboundTrafficPolicy: REGISTRY_ONLY` blocks all outbound traffic except to registered ServiceEntries — implementing network egress control at the mesh level.

### Pitfall 3: Sidecar Resource Starvation
Each Envoy sidecar consumes CPU and memory from the node. In a cluster with 500 Pods, that is 500 additional containers. Without resource requests/limits on the sidecar proxy, Pods can be scheduled onto nodes that appear to have capacity but run out of resources when the sidecars are injected. Always configure `global.proxy.resources.requests` and `limits` in the IstioOperator.

### Pitfall 4: VirtualService Without a Corresponding DestinationRule
A VirtualService that references a `subset` (e.g. `subset: canary`) without a corresponding DestinationRule that defines that subset will result in `503 No healthy upstream` errors. Every subset referenced in a VirtualService must be defined in the DestinationRule for the same host.

### Pitfall 5: Fault Injection Left On in Production
Fault injection (`VirtualService.http.fault`) is a chaos engineering tool for testing. Teams occasionally leave delay or abort faults active after testing, causing degraded service or elevated error rates. Treat fault injection resources as temporary — use Git PR reviews and auto-expiring annotations to prevent them from lingering in production.

### Pitfall 6: Ignoring Proxy Synchronisation Lag
When Istiod pushes configuration changes, Envoy proxies receive updates asynchronously. During a canary deployment, there can be a brief window where some proxies have the new routing rules and some do not, leading to inconsistent traffic distribution. Use `istioctl proxy-status` to verify all proxies are SYNCED before declaring a traffic shift complete.

> **Istio Production Readiness Checklist**
> - [ ] Istio installed with production profile (HA Istiod: ≥2 replicas)
> - [ ] Sidecar resource requests and limits configured
> - [ ] Namespace injection enabled only for namespaces that need the mesh
> - [ ] mTLS migration: PERMISSIVE → validate → STRICT
> - [ ] `outboundTrafficPolicy: REGISTRY_ONLY` enabled; all external hosts registered as ServiceEntries
> - [ ] AuthorizationPolicy `deny-all` in production namespaces; explicit allows for each connection
> - [ ] VirtualService timeouts configured for every external-facing service
> - [ ] Retry policies configured; `perTryTimeout < timeout / attempts`
> - [ ] DestinationRule outlier detection configured for all services
> - [ ] All subsets in VirtualServices have matching DestinationRule definitions
> - [ ] Kiali deployed with Prometheus and Tempo datasources linked
> - [ ] Telemetry resource configured with appropriate sampling rate
> - [ ] Canary Rollouts use Istio VirtualService for precise traffic splitting
> - [ ] Fault injection tests documented; automated cleanup enforced via CI
> - [ ] `istioctl analyze` runs in CI pipeline to catch configuration errors

---

## 10. Key Takeaways

1. **Istio moves networking logic from application code to infrastructure.** Retries, timeouts, circuit breaking, mTLS, and traffic splitting are now Kubernetes CRD configurations applied by platform engineers — not library code embedded in each service by developers. This makes networking behaviour consistent across all services, languages, and runtimes.

2. **The xDS API is the mechanism that makes Istio work.** Istiod continuously pushes Listener, Route, Cluster, and Endpoint configuration to Envoy proxies via gRPC streaming. Understanding this model explains why configuration changes take a few seconds to propagate, why `istioctl proxy-status` shows SYNCED/STALE states, and why proxy synchronisation must be verified after changes.

3. **mTLS with AuthorizationPolicies implements zero-trust networking.** With STRICT mTLS and deny-all AuthorizationPolicies, every service connection requires a valid Istio certificate (proving identity) and an explicit allow rule (proving authorisation). This eliminates entire attack vectors — a compromised container cannot reach the payment service without an explicit policy allowing it.

4. **Fault injection is a first-class Istio feature, not a hack.** The ability to inject delays and HTTP errors via VirtualService resources enables systematic chaos engineering — validating that timeouts are configured correctly, that circuit breakers open when expected, and that degraded dependencies do not cascade into full system failures.

5. **Kiali's service graph is the authoritative source of truth for service dependencies.** Built from real traffic data rather than documentation, the Kiali topology graph shows which services are actually communicating, at what rate, with what error rate — something no amount of architecture documentation can match in accuracy.

6. **Multi-cluster federation extends the zero-trust security model across regions.** With multi-primary Istio, a service in us-east-1 calling a service in eu-west-1 uses the same mTLS certificate infrastructure, the same AuthorizationPolicies, and the same traffic management rules. Geographic distribution becomes a configuration detail, not an architectural discontinuity.

---

## 11. Exercises & Labs

**Exercise 1: Istio Installation and Sidecar Injection**
Install Istio on a test cluster using the `default` profile. Enable sidecar injection for a namespace. Deploy a two-service application (a frontend and an API backend). Verify: (a) both Pods show 2/2 READY, (b) `istioctl proxy-status` shows all proxies SYNCED, (c) `istioctl analyze` reports no errors. Run a request from the frontend to the backend and observe the trace in Jaeger/Tempo.

**Exercise 2: Traffic Shifting with Canary**
Deploy two versions of a service with `version: stable` and `version: canary` labels. Create a DestinationRule with two subsets. Create a VirtualService that starts with 100% stable. Gradually shift traffic to 10%, 30%, 50%, and 100% canary by updating the VirtualService weights. After each shift, use Kiali to visualise the traffic distribution and verify it matches the configured weights.

**Exercise 3: mTLS End-to-End**
Apply a PERMISSIVE PeerAuthentication to your namespace. Verify both mTLS and plain-text requests succeed. Then switch to STRICT. Verify: (a) mTLS requests from meshed Pods still work, (b) plain-text requests from a non-meshed Pod (sidecar.istio.io/inject: "false") are rejected with a connection error. Use `istioctl authn tls-check` to confirm all connections show `mTLS`.

**Exercise 4: Fault Injection Chaos Test**
Deploy a three-service chain (A → B → C). Configure service A with a 3-second timeout on calls to B. Inject a 5-second delay into 100% of requests to B using a VirtualService fault. Verify that: (a) service A returns a 504 timeout error rather than waiting indefinitely, (b) the error is visible in the Kiali service graph as increased latency on the A→B edge, (c) removing the fault injection returns latency to normal. Document the circuit breaker behaviour.

**Exercise 5: AuthorizationPolicy Zero-Trust Rollout**
In a test namespace, apply a `deny-all` AuthorizationPolicy. Verify all inter-service communication breaks. Then add explicit allow policies one connection at a time (frontend → API, API → database, monitoring → all services on `/metrics`). Verify each connection works after its policy is applied. Use `kubectl auth can-i` (Kubernetes RBAC) and Istio `authz check` (`istioctl x authz check <pod>`) to audit the final policy set.

---

## Appendix: Book Completion Summary

You have reached the end of **Mastering DevOps in Kubernetes**. Across thirteen chapters, this book has built a complete, production-grade understanding of the entire Kubernetes ecosystem:

| Chapter | Core Skill |
|---|---|
| 1 | DevOps philosophy, GitOps principles, the 12-Factor App |
| 2 | Docker internals, multi-stage builds, OCI registries, CRI |
| 3 | Core Kubernetes objects, autoscaling, kubectl mastery |
| 4 | Stateful workloads, PVCs, StorageClasses, PostgreSQL, Kafka |
| 5 | Amazon EKS, VPC CNI, IRSA, ALB Controller, CloudWatch |
| 6 | Azure AKS, Azure CNI, Workload Identity, KEDA, Azure DevOps |
| 7 | Google GKE, Autopilot, Dataplane V2, Cloud Armor, Cloud Build |
| 8 | kubeadm, etcd backup/restore, RBAC, Admission Controllers, troubleshooting |
| 9 | 4Cs security, PSA, NetworkPolicy, Vault, Trivy, Falco, CIS Benchmark |
| 10 | Prometheus, Grafana, Loki, Tempo, Alertmanager, SLO dashboards |
| 11 | Helm, Kustomize, Argo CD, Flux CD, progressive delivery |
| 12 | GitHub Actions, Jenkins X, CI/CD pipelines, Argo Rollouts |
| 13 | Istio architecture, mTLS, traffic management, chaos engineering, multi-cluster |

---

*End of Chapter 13 — End of Book*

*Thank you for reading Mastering DevOps in Kubernetes.*
