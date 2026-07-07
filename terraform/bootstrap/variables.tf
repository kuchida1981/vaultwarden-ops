variable "project_id" {
  description = "GCP project ID that will host the Vaultwarden infrastructure."
  type        = string
}

variable "region" {
  description = "Default region for regional resources (state bucket)."
  type        = string
  default     = "asia-northeast1"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the Terraform CI service account, in \"owner/repo\" form."
  type        = string
}
