module "gcp_network" {
  source = "../modules/gcp-network"

  project_id = var.project_id
  region     = var.region
}
