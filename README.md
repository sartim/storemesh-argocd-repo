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

Deployments are manually triggered from the `Deploy with Argo CD` GitHub
Actions workflow. Configure `ARGOCD_SERVER` and `ARGOCD_AUTH_TOKEN` as secrets
on both the `staging` and `production` GitHub Environments. Require reviewers
on the `production` Environment. The workflow accepts an Argo application name
and an optional immutable source revision, then waits for Argo CD sync and
health before succeeding. It does not use direct `kubectl` deployment access.

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

`examples/eck-logging-stack.yaml` is a deliberately non-applied starting
template. Replace its Elastic Stack version and storage class, then review
replica sizing, retention, TLS, and backup settings for the target environment
before applying it.

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

`examples/fluent-bit-eck-values.yaml` provides the non-applied Fluent Bit
pipeline template. Replace the ECK service hostname and inject credentials from
an ExternalSecret-backed Kubernetes Secret before enabling the Fluent Bit
chart. The filters remove common password, token, and authorization fields;
extend the redaction policy for application-specific sensitive fields.

Istio is represented by separate, opt-in `base` and `istiod` applications,
pinned to `1.30.3`. These install the mesh control plane only; sidecar
injection, gateways, mTLS policy, and telemetry providers require a separate
environment review before workloads are enrolled.

`examples/istio-mesh-policy.yaml` is a non-applied migration template. Start
with `PERMISSIVE` mode while sidecars and the Tempo provider are validated,
then promote to `STRICT` in an environment-specific policy after approved
workloads are enrolled. Repeat the policy for each namespace deliberately;
there is no cluster-wide enrollment in this repository.
