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

variable "vaultwarden_image_tag" {
  description = "vaultwarden/server image tag to run."
  type        = string
  default     = "latest"
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
