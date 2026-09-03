output "name" {
  description = "GCS bucket name to use as the terraform/main remote state backend."
  value       = google_storage_bucket.tfstate.name
}
