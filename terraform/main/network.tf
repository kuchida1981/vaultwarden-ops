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

resource "google_compute_address" "vaultwarden" {
  name    = "vaultwarden-static-ip"
  project = var.project_id
  region  = var.region
}
