module "gcp_disk" {
  source = "../modules/gcp-disk"

  project_id = var.project_id
  zone       = var.zone
}
