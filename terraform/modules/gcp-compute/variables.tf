variable "project_id" {
  description = "GCP project ID hosting the VM."
  type        = string
}

variable "zone" {
  description = "Zone for the VM. Must match the data disk's zone."
  type        = string
}

variable "domain" {
  description = "Public domain Vaultwarden is served on."
  type        = string
}

variable "github_repo" {
  description = "Public GitHub repo (owner/repo) the VM clones at boot to get docker-compose.yml/Caddyfile."
  type        = string
}

variable "network_self_link" {
  description = "Self-link of the VPC network to attach the VM's network interface to."
  type        = string
}

variable "static_ip" {
  description = "Static external IP address to assign to the VM."
  type        = string
}

variable "disk_self_link" {
  description = "Self-link of the data disk to attach to the VM."
  type        = string
}

variable "vm_runtime_email" {
  description = "Email of the service account to attach to the VM."
  type        = string
}

variable "admin_token_secret_id" {
  description = "Secret ID of the Vaultwarden admin token, read by the VM at boot."
  type        = string
}

variable "tailscale_authkey_secret_id" {
  description = "Secret ID of the Tailscale auth key, read by the VM at boot."
  type        = string
}

variable "smtp_host" {
  description = "SMTP relay host Vaultwarden sends mail through."
  type        = string
}

variable "smtp_port" {
  description = "SMTP relay port."
  type        = string
}

variable "smtp_security" {
  description = "Vaultwarden SMTP_SECURITY mode (starttls, force_tls, or off)."
  type        = string
}

variable "smtp_from" {
  description = "Send-only From address for Vaultwarden-originated mail."
  type        = string
}

variable "smtp_from_name" {
  description = "Display name used alongside smtp_from."
  type        = string
}

variable "smtp_username_secret_id" {
  description = "Secret ID of the SMTP username, read by the VM at boot."
  type        = string
}

variable "smtp_password_secret_id" {
  description = "Secret ID of the SMTP password, read by the VM at boot."
  type        = string
}

variable "nas_backup_host" {
  description = "Tailscale MagicDNS hostname (or IP) of the NAS the VM backs up to."
  type        = string
}

variable "nas_backup_module" {
  description = "rsync daemon module name on the NAS that receives the backup."
  type        = string
}

variable "nas_backup_username" {
  description = "rsync daemon account name configured on the NAS for backups."
  type        = string
}

variable "nas_backup_password_secret_id" {
  description = "Secret ID of the NAS backup rsync password, read by the VM at boot."
  type        = string
}
