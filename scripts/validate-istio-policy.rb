#!/usr/bin/env ruby

require "yaml"

policy_path = File.expand_path("../manifests/istio-mesh/policy.yaml", __dir__)
documents = YAML.load_stream(File.read(policy_path))

namespaces = %w[
  storemesh-user-service
  storemesh-product-service
  storemesh-inventory-service
  storemesh-order-service
  storemesh-bff
  storemesh-frontend
]

peer_auth = documents.select { |doc| doc.is_a?(Hash) && doc["kind"] == "PeerAuthentication" }
actual_peer_namespaces = peer_auth.map { |doc| doc.dig("metadata", "namespace") }.sort
expected_peer_namespaces = namespaces.sort
abort "PeerAuthentication namespaces mismatch: #{actual_peer_namespaces.inspect}" unless actual_peer_namespaces == expected_peer_namespaces

unless peer_auth.all? { |doc| doc.dig("spec", "mtls", "mode") == "STRICT" }
  abort "Every StoreMesh PeerAuthentication must use STRICT mTLS"
end

authorization = documents.select { |doc| doc.is_a?(Hash) && doc["kind"] == "AuthorizationPolicy" }
actual_authorization_namespaces = authorization.map { |doc| doc.dig("metadata", "namespace") }.sort
abort "AuthorizationPolicy namespaces mismatch: #{actual_authorization_namespaces.inspect}" unless actual_authorization_namespaces == expected_peer_namespaces

puts "Istio policy contract is valid: #{peer_auth.length} STRICT PeerAuthentication and #{authorization.length} AuthorizationPolicy resources."
