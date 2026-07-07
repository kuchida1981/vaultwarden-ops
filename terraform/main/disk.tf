# Vaultwarden's data (SQLite DB, RSA keys, attachments) lives on a disk
# that is independent of the VM's lifecycle. If the VM is ever destroyed
# and recreated (e.g. due to a machine-type change), this disk survives
# and is simply reattached, so no data is lost.
resource "google_compute_disk" "vaultwarden_data" {
  name    = "vaultwarden-data"
  project = var.project_id
  zone    = var.zone
  type    = "pd-standard"
  size    = 10

  lifecycle {
    prevent_destroy = true
  }
}
