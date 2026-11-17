module "gcp_disk" {
  source = "../modules/gcp-disk"

  project_id = var.project_id
  zone       = var.zone

  source_snapshot = var.data_disk_source_snapshot
}
