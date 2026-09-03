output "vm_runtime_email" {
  description = "Email of the VM runtime service account, for attaching to the VM."
  value       = google_service_account.vm_runtime.email
}
