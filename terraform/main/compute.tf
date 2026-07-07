resource "google_compute_instance" "vaultwarden" {
  name         = "vaultwarden"
  project      = var.project_id
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["vaultwarden-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
      size  = 20
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.vaultwarden_data.self_link
    device_name = "vaultwarden-data"
  }

  network_interface {
    network = data.google_compute_network.default.self_link

    access_config {
      nat_ip = google_compute_address.vaultwarden.address
    }
  }

  service_account {
    email  = google_service_account.vm_runtime.email
    scopes = ["cloud-platform"]
  }

  # Free hardening with no cost or capability trade-off for this workload.
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    startup-script = templatefile("${path.module}/templates/startup-script.sh.tftpl", {
      project_id      = var.project_id
      domain          = var.domain
      github_repo     = var.github_repo
      admin_secret_id = google_secret_manager_secret.admin_token.secret_id
      ts_secret_id    = google_secret_manager_secret.tailscale_authkey.secret_id
    })
  }

  depends_on = [
    google_secret_manager_secret_version.admin_token,
    google_secret_manager_secret_version.tailscale_authkey,
    google_secret_manager_secret_iam_member.admin_token_access,
    google_secret_manager_secret_iam_member.tailscale_authkey_access,
  ]
}
