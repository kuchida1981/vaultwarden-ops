output "self_link" {
  description = "Self-link of the data disk, for attaching to the VM."
  value       = google_compute_disk.vaultwarden_data.self_link
}
