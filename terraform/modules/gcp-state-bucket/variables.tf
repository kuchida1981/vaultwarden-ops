variable "project_id" {
  description = "GCP project ID hosting the state bucket."
  type        = string
}

variable "region" {
  description = "Region (as a GCS location) for the state bucket."
  type        = string
}
