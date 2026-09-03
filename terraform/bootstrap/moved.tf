# State migration for the gcp-* module split (see openspec/changes/
# terraform-module-split). Each block maps a pre-split resource address to
# its new module-qualified address, so `terraform apply` reattaches the
# existing GCS-backed resource instead of destroying and recreating it.
# Resource local names are unchanged from the pre-split file - only their
# address prefix (module.gcp_xxx.) changed.
#
# vaultwarden_vm_monitoring_writer/vaultwarden_vm_logging_writer aren't
# here: they were never modularized, so their address didn't change.

# main.tf -> module.gcp_project_apis
moved {
  from = google_project_service.required
  to   = module.gcp_project_apis.google_project_service.required
}

# main.tf -> module.gcp_state_bucket
moved {
  from = google_storage_bucket.tfstate
  to   = module.gcp_state_bucket.google_storage_bucket.tfstate
}

# main.tf -> module.gcp_wif
moved {
  from = google_iam_workload_identity_pool.github
  to   = module.gcp_wif.google_iam_workload_identity_pool.github
}

moved {
  from = google_iam_workload_identity_pool_provider.github
  to   = module.gcp_wif.google_iam_workload_identity_pool_provider.github
}

# main.tf -> module.gcp_ci_service_account
moved {
  from = google_service_account.terraform_ci
  to   = module.gcp_ci_service_account.google_service_account.terraform_ci
}

moved {
  from = google_service_account_iam_member.wif_binding
  to   = module.gcp_ci_service_account.google_service_account_iam_member.wif_binding
}

moved {
  from = google_storage_bucket_iam_member.terraform_ci_state_access
  to   = module.gcp_ci_service_account.google_storage_bucket_iam_member.terraform_ci_state_access
}

moved {
  from = google_project_iam_member.terraform_ci_roles
  to   = module.gcp_ci_service_account.google_project_iam_member.terraform_ci_roles
}

moved {
  from = google_storage_bucket_iam_member.terraform_ci_state_bucket_reader
  to   = module.gcp_ci_service_account.google_storage_bucket_iam_member.terraform_ci_state_bucket_reader
}
