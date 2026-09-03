variable "project_id" {
  description = "GCP project ID hosting the Workload Identity Pool."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the Terraform CI service account, in \"owner/repo\" form."
  type        = string
}
