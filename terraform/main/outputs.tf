output "vm_external_ip" {
  description = "Static external IP to point vaultwarden.u-rei.com's A record at."
  value       = module.gcp_network.address
}

output "vm_name" {
  description = "GCE instance name, used as the Tailscale hostname for `tailscale ssh`."
  value       = module.gcp_compute.vm_name
}
