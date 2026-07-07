output "vm_external_ip" {
  description = "Static external IP to point vaultwarden.u-rei.com's A record at."
  value       = google_compute_address.vaultwarden.address
}

output "vm_name" {
  description = "GCE instance name, used as the Tailscale hostname for `tailscale ssh`."
  value       = google_compute_instance.vaultwarden.name
}
