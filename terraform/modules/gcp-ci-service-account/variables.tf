variable "project_id" {
  description = "GCP project ID hosting the CI service account."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the Terraform CI service account, in \"owner/repo\" form."
  type        = string
}

variable "workload_identity_pool_name" {
  description = "Full resource name of the Workload Identity Pool the CI service account is bound to."
  type        = string
}

variable "state_bucket_name" {
  description = "GCS bucket name the CI service account needs read/write access to."
  type        = string
}
