variable "project_id" {
  description = "GCP project ID hosting the secrets."
  type        = string
}

variable "tailscale_authkey" {
  description = "Tailscale auth key value to persist for the VM to read at boot."
  type        = string
  sensitive   = true
}

variable "smtp_username" {
  description = "SMTP login issued by the mail relay provider (Brevo)."
  type        = string
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP key/password issued by the mail relay provider (Brevo)."
  type        = string
  sensitive   = true
}

variable "nas_backup_password" {
  description = "rsync daemon password for the NAS backup account."
  type        = string
  sensitive   = true
}
