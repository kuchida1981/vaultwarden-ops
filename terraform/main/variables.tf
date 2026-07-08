variable "project_id" {
  description = "GCP project ID hosting the Vaultwarden infrastructure."
  type        = string
}

variable "region" {
  description = "Region for regional resources."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zone for the VM and its data disk."
  type        = string
  default     = "asia-northeast1-b"
}

variable "domain" {
  description = "Public domain Vaultwarden is served on."
  type        = string
  default     = "vaultwarden.u-rei.com"
}

variable "github_repo" {
  description = "Public GitHub repo (owner/repo) the VM clones at boot to get docker-compose.yml/Caddyfile."
  type        = string
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet identifier (e.g. example.ts.net or an org name)."
  type        = string
}

variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID used by the tailscale Terraform provider."
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret used by the tailscale Terraform provider."
  type        = string
  sensitive   = true
}

variable "smtp_host" {
  description = "SMTP relay host Vaultwarden sends mail through."
  type        = string
  default     = "smtp-relay.brevo.com"
}

variable "smtp_port" {
  description = "SMTP relay port."
  type        = string
  default     = "587"
}

variable "smtp_security" {
  description = "Vaultwarden SMTP_SECURITY mode (starttls, force_tls, or off)."
  type        = string
  default     = "starttls"
}

variable "smtp_from" {
  description = "Send-only From address for Vaultwarden-originated mail."
  type        = string
  default     = "vaultwarden@u-rei.com"
}

variable "smtp_from_name" {
  description = "Display name used alongside smtp_from."
  type        = string
  default     = "vaultwarden"
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
