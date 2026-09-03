terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

# Remote state bucket used by terraform/main.
resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-vaultwarden-tfstate"
  project                     = var.project_id
  location                    = upper(var.region)
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}
