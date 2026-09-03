output "tailnet_key" {
  description = "Auth key value for the VM to join the tailnet at boot."
  value       = tailscale_tailnet_key.vm.key
  sensitive   = true
}
