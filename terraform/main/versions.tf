terraform {
  # >= 1.7.0 (bumped from 1.6.0 for the gcp-* module split): moved.tf moves
  # data.google_compute_network.default into a module, and moved blocks for
  # data resources are only supported from Terraform 1.7 onward.
  required_version = ">= 1.7.0"

  backend "gcs" {
    # bucket is supplied at `terraform init` time via -backend-config,
    # using the state_bucket output from terraform/bootstrap.
    prefix = "vaultwarden/main"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "tailscale" {
  tailnet             = var.tailscale_tailnet
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
}
