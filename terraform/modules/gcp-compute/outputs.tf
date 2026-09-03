output "vm_name" {
  description = "GCE instance name, used as the Tailscale hostname for `tailscale ssh`."
  value       = google_compute_instance.vaultwarden.name
}
