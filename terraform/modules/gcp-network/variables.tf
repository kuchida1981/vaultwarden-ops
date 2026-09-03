variable "project_id" {
  description = "GCP project ID hosting the network resources."
  type        = string
}

variable "region" {
  description = "Region for the static external IP."
  type        = string
}
