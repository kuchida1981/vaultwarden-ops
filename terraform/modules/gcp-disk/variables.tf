variable "project_id" {
  description = "GCP project ID hosting the disk."
  type        = string
}

variable "zone" {
  description = "Zone for the data disk. Must match the VM's zone."
  type        = string
}
