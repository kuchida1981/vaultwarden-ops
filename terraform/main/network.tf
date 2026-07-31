# Uses the project's default auto-mode VPC; a personal single-VM deployment
# doesn't need a dedicated network.
data "google_compute_network" "default" {
  name    = "default"
  project = var.project_id
}

resource "google_compute_firewall" "allow_web" {
  name    = "vaultwarden-allow-web"
  project = var.project_id
  network = data.google_compute_network.default.self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vaultwarden-server"]
}

# Deliberately no firewall rule opens port 22 (or any other port) to the
# public internet. All administrative access happens over `tailscale ssh`,
# which tunnels through the Tailscale WireGuard interface rather than GCP's
# network stack, so no corresponding ingress rule is needed here.
#
# vaultwarden-deploy.yml reaches the VM via `gcloud compute ssh
# --tunnel-through-iap` (see add-vaultwarden-deploy-pipeline's design.md),
# which - unlike `tailscale ssh` - actually forwards a tcp:22 packet into the
# VPC via IAP, so it needs its own ingress rule. Scoped to IAP's documented
# source range only, and to this VM's tag only - no other source can reach
# tcp:22 through this rule.
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "vaultwarden-allow-iap-ssh"
  project = var.project_id
  network = data.google_compute_network.default.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["vaultwarden-server"]
}

resource "google_compute_address" "vaultwarden" {
  name    = "vaultwarden-static-ip"
  project = var.project_id
  region  = var.region

  labels = {
    app = "vaultwarden"
  }
}
