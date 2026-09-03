variable "project_id" {
  description = "GCP project ID hosting the IAM resources."
  type        = string
}

variable "admin_token_secret_id" {
  description = "Secret ID of the Vaultwarden admin token, granted to the VM runtime SA."
  type        = string
}

variable "tailscale_authkey_secret_id" {
  description = "Secret ID of the Tailscale auth key, granted to the VM runtime SA."
  type        = string
}

variable "smtp_username_secret_id" {
  description = "Secret ID of the SMTP username, granted to the VM runtime SA."
  type        = string
}

variable "smtp_password_secret_id" {
  description = "Secret ID of the SMTP password, granted to the VM runtime SA."
  type        = string
}

variable "nas_backup_password_secret_id" {
  description = "Secret ID of the NAS backup rsync password, granted to the VM runtime SA."
  type        = string
}
