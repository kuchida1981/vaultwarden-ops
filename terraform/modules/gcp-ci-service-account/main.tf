terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

# Service account impersonated by GitHub Actions to run terraform/main.
resource "google_service_account" "terraform_ci" {
  project      = var.project_id
  account_id   = "terraform-ci"
  display_name = "Terraform CI (GitHub Actions)"
}

resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.terraform_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.github_repo}"
}

resource "google_storage_bucket_iam_member" "terraform_ci_state_access" {
  bucket = var.state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# Broad-but-scoped project roles the CI service account needs to manage
# the VM, disks, firewall, Secret Manager entries and the VM runtime SA.
#
# iap.tunnelResourceAccessor + compute.osAdminLogin: lets vaultwarden-deploy.yml
# reach the VM via `gcloud compute ssh --tunnel-through-iap` to run
# `docker compose pull && up -d` after a version bump, without touching the
# Tailscale ACL (which is already jointly owned by n8n-ops' state - see
# Issue #12). OS Login mints short-lived SSH keys tied to this SA's own IAM
# identity, so there's no persistent key to manage or rotate. osAdminLogin
# (not the plain osLogin) is required specifically because
# /opt/vaultwarden/app, /opt/vaultwarden/.env (mode 600) and the docker
# socket are all root-owned - the deploy command needs sudo, which only
# osAdminLogin grants via OS Login's sudoers group.
resource "google_project_iam_member" "terraform_ci_roles" {
  for_each = toset([
    "roles/compute.admin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iap.tunnelResourceAccessor",
    "roles/compute.osAdminLogin",
    # Read-only roles below let CI `terraform plan` refresh terraform/bootstrap's
    # own resources (project services, WIF pool/provider, project IAM
    # bindings) without granting any ability to change them. terraform/bootstrap
    # is never applied by CI - see terraform-plan.yml's plan-bootstrap job.
    "roles/serviceusage.serviceUsageViewer",
    "roles/iam.workloadIdentityPoolViewer",
    "roles/iam.securityReviewer",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# roles/storage.objectAdmin above (terraform_ci_state_access) only grants
# object-level access, not storage.buckets.get - needed to refresh the
# google_storage_bucket.tfstate resource itself during `terraform plan`.
resource "google_storage_bucket_iam_member" "terraform_ci_state_bucket_reader" {
  bucket = var.state_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.terraform_ci.email}"
}
