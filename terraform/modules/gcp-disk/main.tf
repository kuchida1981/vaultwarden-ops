terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

# Vaultwarden's data (SQLite DB, RSA keys, attachments) lives on a disk
# that is independent of the VM's lifecycle. If the VM is ever destroyed
# and recreated (e.g. due to a machine-type change), this disk survives
# and is simply reattached, so no data is lost.
resource "google_compute_disk" "vaultwarden_data" {
  name    = "vaultwarden-data"
  project = var.project_id
  zone    = var.zone
  # pd-standard (HDD-backed) so the disk fits the GCP always-free tier
  # (30 GB-months of standard PD per billing account). SQLite fsyncs on
  # every write, so if responsiveness suffers, switching back to
  # pd-balanced (SSD-backed) costs only cents to a few dollars per month.
  type = "pd-standard"
  size = 10

  # Set only when restoring/migrating from a snapshot (e.g. a cross-region
  # move, since zonal disks can't leave their zone). null = empty disk.
  snapshot = var.source_snapshot

  labels = {
    app = "vaultwarden"
  }

  lifecycle {
    prevent_destroy = true
    # The snapshot is only an initialization source. Ignoring it lets
    # source_snapshot be set back to null after a migration without
    # forcing the disk to be replaced.
    ignore_changes = [snapshot]
  }
}
