variable "project_id" {
  description = "GCP project ID hosting the disk."
  type        = string
}

variable "zone" {
  description = "Zone for the data disk. Must match the VM's zone."
  type        = string
}

variable "source_snapshot" {
  description = "Snapshot (name or self_link) to initialize the disk from, used when migrating across zones/regions. null creates an empty disk."
  type        = string
  default     = null
}
