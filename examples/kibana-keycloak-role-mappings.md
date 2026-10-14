# Kibana role mapping for Keycloak

This procedure is gated on an Elastic license that includes OIDC SSO. The
default free Basic license does not include Elastic Stack SSO. Check the
cluster license before enabling the OIDC realm; keep the native ECK `elastic`
account as the break-glass login.

The ECK example maps Keycloak's `groups` ID-token claim to Elasticsearch's
OIDC `groups` user property. Once the OIDC realm is active, assign only
explicitly approved groups to Elastic roles. These requests are illustrative;
run them against the correct environment over verified TLS, using an
administrative credential supplied interactively or through an approved
secret manager. Do not put passwords, API keys, or client secrets in Git or
command history.

For a platform operator who needs read-only visibility, map `operator` to the
built-in `viewer` role:

```http
PUT /_security/role_mapping/storemesh-observability-viewer
{
  "enabled": true,
  "roles": ["viewer"],
  "rules": {
    "all": [
      { "field": { "realm.name": "oidc1" } },
      { "field": { "groups": "operator" } }
    ]
  },
  "metadata": { "managed_by": "storemesh" }
}
```

For the dedicated observability administrator, map `observability-admin` to
`kibana_admin`:

```http
PUT /_security/role_mapping/storemesh-observability-admin
{
  "enabled": true,
  "roles": ["kibana_admin"],
  "rules": {
    "all": [
      { "field": { "realm.name": "oidc1" } },
      { "field": { "groups": "observability-admin" } }
    ]
  },
  "metadata": { "managed_by": "storemesh" }
}
```

The built-in `viewer` role grants read access broadly across Kibana and
non-hidden data indices. For multi-team or production data, replace it with a
custom least-privilege role scoped to the intended index patterns and Kibana
space. Never map a general `admin` Keycloak role to `superuser` for routine
observability access.

References: [Elastic OIDC claims and role mappings](https://www.elastic.co/guide/en/elasticsearch/reference/current/oidc-guide.html),
[Elastic role mapping API](https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-security-put-role-mapping),
and [Elastic license availability](https://www.elastic.co/docs/deploy-manage/users-roles/cluster-or-deployment-auth/kibana-authentication).
