# StoreMesh Argo CD repository

This repository contains the Argo CD `AppProject` and application definitions
for StoreMesh.

Pull requests run manifest CI that parses every YAML document and checks for
whitespace errors. Kubernetes schema validation remains environment-specific
because several examples intentionally contain placeholders and require CRDs.

The user-service application deploys the chart from
`sartim/storemesh-helm-repo`. Runtime credentials are supplied through the
`storemesh-user-service-secrets` Kubernetes Secret; no secret values belong in
Git.

Apply the project and application after Argo CD is installed:

```sh
kubectl apply -f project.yaml
kubectl apply -f storemesh-user-service-application.yaml
```

Argo CD application manifests are retained for a future GitOps deployment
model, but they are not the active deployment path until a reachable Argo CD
server is available. The current manual deployment workflow is in the Helm
repository and runs `helm upgrade --install` from GitHub Actions.

The cert-manager application is intentionally separate and should be enabled
only in environments with an ingress controller and an approved certificate
issuance policy:

```sh
kubectl apply -f cert-manager-application.yaml
```

It tracks the official Jetstack OCI chart at a pinned version and manages the
cert-manager CRDs through Argo CD.

After cert-manager is healthy, copy and customize
`examples/letsencrypt-clusterissuer.yaml` with a real ACME account email and
the ingress class used by the environment. Apply it only after DNS points the
User Service hostname at the ingress controller. The template is deliberately
not included in the Argo application sync set because its values are
environment-specific.

The ECK operator is also an explicitly applied, opt-in application. It is
pinned to ECK `3.4.1` and installs the Elasticsearch/Kibana custom resource
definitions; it does not create a logging cluster by itself:

```sh
kubectl apply -f eck-operator-application.yaml
```

Declare environment-specific Elasticsearch and Kibana resources only after
the operator is healthy. Configure persistent storage, retention, credentials,
network policy, and backups before sending production logs.

The local bootstrap also submits `eck-logging-application.yaml`, which applies
the ECK-managed one-node Elasticsearch/Kibana stack in `storemesh-logging`.
`manifests/eck-logging/stack.yaml` is intentionally small for Kind and uses
ECK's generated TLS and `elastic` credentials. Increase replicas, storage,
retention, and backup settings before using it in a shared or production
environment. `examples/eck-logging-stack.yaml` remains the environment-specific
template for that review.

`fluent-bit-application.yaml` deploys a local DaemonSet after the ECK stack and
sends redacted container logs to the ECK Elasticsearch service. TLS verification
is disabled only for this temporary local Kind setup; use the ECK CA secret and
an ExternalSecret-backed credential in shared environments.

Kiali is installed through its operator application and is configured for
anonymous local access only. It observes Istio and Prometheus and should be
protected with an approved authentication strategy outside local testing.

Non-applied OIDC examples for Grafana and Argo CD are in
`examples/grafana-keycloak-values.yaml` and
`examples/argocd-keycloak-oidc.yaml`. They intentionally use placeholders and
must be adapted for the environment: create confidential-client Secrets out
of band, use an issuer reachable by the server, register exact HTTPS callback
URLs in Keycloak, and verify group-to-role mappings before removing local
fallback access. Kiali and Kibana require the same explicit tool-specific
activation process.

`storemesh-keycloak-application.yaml` is the matching opt-in Argo CD
Application. It is deliberately not submitted by the default local bootstrap.
To enable it, create the admin Secret out of band and apply the Application:

```sh
kubectl create namespace storemesh-keycloak --dry-run=client -o yaml | kubectl apply -f -
kubectl -n storemesh-keycloak create secret generic storemesh-keycloak-admin \
  --from-literal=password="$KEYCLOAK_ADMIN_PASSWORD"
kubectl apply -f storemesh-keycloak-application.yaml
```

Wait for Keycloak readiness before applying the service OIDC values example.

The BFF, Product, Order, and Inventory applications expose explicit
`config.keycloakIssuer` and `config.keycloakAudience` Helm values. They are
empty by default so the local smoke deployment does not depend on the
optional Keycloak chart. After installing Keycloak and confirming its realm is
healthy, apply the values in
`examples/service-keycloak-oidc-values.yaml` to each application, using the
actual Keycloak namespace. The issuer must exactly match the token `iss`
claim; do not configure an internal cluster issuer while clients are obtaining
tokens from a different external issuer.

The Prometheus Operator-compatible stack is an explicitly applied, opt-in
application pinned to `kube-prometheus-stack` `88.5.4`:

```sh
kubectl apply -f prometheus-stack-application.yaml
```

It installs Prometheus, Grafana, Alertmanager, and their CRDs in the
`storemesh-monitoring` namespace. Configure persistent storage, ingress,
authentication, and resource limits in an environment overlay before enabling
it for production.

The Tempo trace backend is an explicitly applied, opt-in application using the
maintained Grafana Community `tempo` chart pinned to `2.3.0`:

```sh
kubectl apply -f tempo-application.yaml
```

It exposes OTLP gRPC and HTTP receivers internally and uses a persistent local
volume by default. Production environments should replace the storage backend,
retention, sizing, and access policy with approved environment values.

The self-hosted Flagsmith application is also explicitly opt-in. It uses the
official Flagsmith chart pinned to `0.83.0`, a disposable internal PostgreSQL
dependency, and no ingress by default:

```sh
kubectl apply -f storemesh-flagsmith-application.yaml
```

After the Flagsmith bootstrap job creates the local project, create a
server-side environment key in the Flagsmith UI and store it in a Kubernetes
Secret. Enable the BFF chart's `flagsmith.enabled` setting and reference that
Secret. Flagsmith is not required for cluster bootstrap because the BFF uses
safe defaults when no key is configured. Use persistent storage, external
PostgreSQL, TLS, and protected administration before shared-environment use.

`examples/fluent-bit-eck-values.yaml` provides the non-applied Fluent Bit
pipeline template. Replace the ECK service hostname and inject credentials from
an ExternalSecret-backed Kubernetes Secret before enabling the Fluent Bit
chart. The filters remove common password, token, and authorization fields;
extend the redaction policy for application-specific sensitive fields.

Istio is represented by separate, opt-in `base`, `istiod`, ingress-gateway, and
mesh-policy applications, pinned to `1.30.3`. The User, Product, Inventory,
Order, BFF, and frontend namespaces are labeled for sidecar injection when
their applications are synchronized. The mesh policy starts in `PERMISSIVE`
mode so existing direct gRPC traffic remains compatible during validation;
promote deliberately to `STRICT` only after every participating workload has a
healthy sidecar and mTLS telemetry has been verified.

`examples/istio-mesh-policy.yaml` is a non-applied migration template. Start
with `PERMISSIVE` mode while sidecars and the Tempo provider are validated,
then promote to `STRICT` in an environment-specific policy after approved
workloads are enrolled. Repeat the policy for each namespace deliberately;
there is no cluster-wide enrollment in this repository.
The `examples/istio-strict-grpc-policy.yaml` file is the corresponding
non-applied promotion template for the four domain-service namespaces.
