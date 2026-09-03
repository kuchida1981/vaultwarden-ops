terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

resource "google_compute_instance" "vaultwarden" {
  name         = "vaultwarden"
  project      = var.project_id
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["vaultwarden-server"]

  # Lets Billing Reports be grouped by label to see vaultwarden's compute
  # cost separately from n8n's, since both VMs live in the same project.
  labels = {
    app = "vaultwarden"
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
      size  = 20
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = var.disk_self_link
    device_name = "vaultwarden-data"
  }

  network_interface {
    network = var.network_self_link

    access_config {
      nat_ip = var.static_ip
    }
  }

  service_account {
    email  = var.vm_runtime_email
    scopes = ["cloud-platform"]
  }

  # Free hardening with no cost or capability trade-off for this workload.
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    # Lets vaultwarden-deploy.yml reach this VM via `gcloud compute ssh
    # --tunnel-through-iap` under the CI service account's own IAM identity
    # (roles/compute.osAdminLogin, granted in terraform/bootstrap), without a
    # persistent SSH key to manage. Does not affect `tailscale ssh`, which
    # tunnels through the Tailscale WireGuard interface and never consults
    # OS Login.
    enable-oslogin = "TRUE"

    startup-script = templatefile("${path.module}/templates/startup-script.sh.tftpl", {
      project_id                    = var.project_id
      domain                        = var.domain
      github_repo                   = var.github_repo
      admin_secret_id               = var.admin_token_secret_id
      ts_secret_id                  = var.tailscale_authkey_secret_id
      smtp_host                     = var.smtp_host
      smtp_port                     = var.smtp_port
      smtp_security                 = var.smtp_security
      smtp_from                     = var.smtp_from
      smtp_from_name                = var.smtp_from_name
      smtp_username_secret_id       = var.smtp_username_secret_id
      smtp_password_secret_id       = var.smtp_password_secret_id
      nas_backup_host               = var.nas_backup_host
      nas_backup_module             = var.nas_backup_module
      nas_backup_username           = var.nas_backup_username
      nas_backup_password_secret_id = var.nas_backup_password_secret_id
    })
  }
}
