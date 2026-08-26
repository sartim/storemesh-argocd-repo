# StoreMesh Argo CD repository

This repository contains the Argo CD `AppProject` and application definitions
for StoreMesh.

The user-service application deploys the chart from
`sartim/storemesh-helm-repo`. Runtime credentials are supplied through the
`storemesh-user-service-secrets` Kubernetes Secret; no secret values belong in
Git.

Apply the project and application after Argo CD is installed:

```sh
kubectl apply -f project.yaml
kubectl apply -f storemesh-user-service-application.yaml
```

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
