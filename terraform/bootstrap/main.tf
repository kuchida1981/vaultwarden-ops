module "gcp_project_apis" {
  source = "../modules/gcp-project-apis"

  project_id = var.project_id
}

module "gcp_state_bucket" {
  source = "../modules/gcp-state-bucket"

  project_id = var.project_id
  region     = var.region

  depends_on = [module.gcp_project_apis]
}

module "gcp_wif" {
  source = "../modules/gcp-wif"

  project_id  = var.project_id
  github_repo = var.github_repo

  depends_on = [module.gcp_project_apis]
}

module "gcp_ci_service_account" {
  source = "../modules/gcp-ci-service-account"

  project_id                  = var.project_id
  github_repo                 = var.github_repo
  workload_identity_pool_name = module.gcp_wif.pool_name
  state_bucket_name           = module.gcp_state_bucket.name
}

# Lets the Ops Agent installed on the vaultwarden VM (see terraform/main's
# startup-script.sh.tftpl) report memory/disk/process metrics and logs to
# Cloud Monitoring/Logging. Granted here rather than in terraform/main
# alongside the rest of that SA's roles (iam.tf) because this is a
# project-level IAM policy change, and terraform-ci is deliberately never
# given resourcemanager.projects.setIamPolicy - see gcp-ci-service-account's
# terraform_ci_roles comment for why an apply-capable CI identity must not be
# able to grant IAM roles itself. The member string is built from the
# account_id literal ("vaultwarden-vm") rather than a resource reference,
# since that service account is a resource in terraform/main's own state, a
# separate root module this one has no data source into.
#
# Left un-modularized (unlike everything else in this file): this is the
# only real cross-module dependency between bootstrap and main - a
# statement about bootstrap's own structure, not a reusable component. A
# dedicated module would have no reuse value and would only bury this
# comment's context one layer deeper.
resource "google_project_iam_member" "vaultwarden_vm_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:vaultwarden-vm@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "vaultwarden_vm_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:vaultwarden-vm@${var.project_id}.iam.gserviceaccount.com"
}
