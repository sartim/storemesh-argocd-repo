#!/usr/bin/env ruby

require "yaml"

def load_yaml(path)
	YAML.load_file(path)
end

def fail_with(message)
  abort(message)
end

grafana = load_yaml("examples/grafana-keycloak-values.yaml").fetch("grafana")
oauth = grafana.fetch("grafana.ini").fetch("auth.generic_oauth")
unless oauth["allow_sign_up"] == true &&
       oauth["groups_attribute_path"] == "groups" &&
       oauth["allowed_groups"].split.sort == %w[observability-admin operator] &&
       oauth["role_attribute_strict"] == true &&
       oauth["role_attribute_path"].include?("observability-admin") &&
       oauth["role_attribute_path"].include?("'Admin'")
  fail_with("Grafana must allow only approved groups and strictly map observability-admin to Admin")
end
unless grafana["envFromSecret"] == "storemesh-grafana-keycloak"
  fail_with("Grafana OIDC client secret must come from a Kubernetes Secret")
end

kiali = load_yaml("examples/kiali-keycloak-values.yaml").fetch("cr").fetch("spec")
unless kiali.dig("auth", "strategy") == "openid" &&
       kiali.dig("auth", "openid", "disable_rbac") != true &&
       !kiali.dig("auth", "openid").key?("client_secret")
  fail_with("Kiali must keep Kubernetes RBAC enabled and must not inline its client secret")
end
unless File.read("examples/kiali-keycloak-values.yaml").include?("oidc-secret")
  fail_with("Kiali OIDC Secret instructions must use the oidc-secret key")
end

kibana = load_yaml("examples/kibana-keycloak-values.yaml")
es_config = kibana.dig("elasticsearch", "spec", "config") || {}
providers = kibana.dig("kibana", "config", "xpack.security.authc.providers") || {}
unless es_config["xpack.security.authc.realms.oidc.oidc1.claims.groups"] == "groups" &&
       providers["oidc.oidc1.order"] < providers["basic.basic1.order"]
  fail_with("Kibana must map the groups claim and order OIDC before the native break-glass provider")
end
license_notes = File.read("examples/kibana-keycloak-values.yaml")
unless license_notes.include?("not the default free Basic license")
  fail_with("Kibana OIDC example must disclose its license requirement")
end
role_mapping_notes = File.read("examples/kibana-keycloak-role-mappings.md")
unless role_mapping_notes.include?("observability-admin") && role_mapping_notes.include?("operator")
  fail_with("Kibana role mapping examples must cover both approved platform roles")
end

argocd_documents = YAML.load_stream(File.read("examples/argocd-keycloak-oidc.yaml"))
argocd_cm = argocd_documents.find { |document| document.is_a?(Hash) && document["kind"] == "ConfigMap" }
fail_with("Argo CD ConfigMap OIDC example is missing") unless argocd_cm
data = argocd_cm.fetch("data")
oidc = YAML.safe_load(data.fetch("oidc.config"))
unless data["policy.default"] == "role:readonly" &&
       data.fetch("policy.csv").include?("g, admin, role:admin") &&
       oidc.fetch("requestedScopes").include?("groups") &&
       oidc.dig("requestedIDTokenClaims", "groups", "essential") == true
  fail_with("Argo CD must request group claims, default to read-only, and map only the admin group to admin")
end
unless File.read("examples/argocd-keycloak-oidc.yaml").include?("/auth/callback")
  fail_with("Argo CD OIDC example must document the exact callback endpoint")
end

puts "Platform OIDC role and secret examples are valid"
