output "network_self_link" {
  description = "Self-link of the default VPC network, for attaching compute resources."
  value       = data.google_compute_network.default.self_link
}

output "address" {
  description = "Static external IP address."
  value       = google_compute_address.vaultwarden.address
}
