# Vaultwarden's data (SQLite DB, RSA keys, attachments) lives on a disk
# that is independent of the VM's lifecycle. If the VM is ever destroyed
# and recreated (e.g. due to a machine-type change), this disk survives
# and is simply reattached, so no data is lost.
resource "google_compute_disk" "vaultwarden_data" {
  name    = "vaultwarden-data"
  project = var.project_id
  zone    = var.zone
  # pd-balanced (SSD-backed) rather than pd-standard (HDD-backed): SQLite
  # fsyncs on every write, and pd-standard's IOPS ceiling is low enough to
  # noticeably affect responsiveness even at this small scale.
  type = "pd-balanced"
  size = 10

  lifecycle {
    prevent_destroy = true
  }
}
