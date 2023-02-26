resource "google_compute_global_address" "gke_global_ip" {
  name    = "gke-global-ip"
  project = var.project
}

resource "google_service_account" "container_sa" {
  project      = var.project
  account_id   = "container-sa"
  display_name = "Container service account"
}

resource "google_project_iam_member" "add_editor_role" {
  project = var.project
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.container_sa.email}"
}

resource "google_compute_network" "gke_network" {
  project = var.project
  name    = "gke-network"
}

resource "google_compute_subnetwork" "gke_subnet" {
  project       = var.project
  name          = "gke-subnet"
  network       = google_compute_network.gke_network.id
  region        = "asia-northeast1"
  ip_cidr_range = "10.0.0.0/15"
}

resource "google_compute_firewall" "ssh_port" {
  project       = var.project
  name          = "allow-ssh"
  network       = google_compute_network.gke_network.name
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags = ["ssh"]
}

resource "google_container_cluster" "gke_cluster" {
  project  = var.project
  name     = "gke-cluster"
  location = "asia-northeast1"

  remove_default_node_pool = true
  initial_node_count       = 1
  # cluster_ipv4_cidr        = "10.0.1.16/28" # 10.0.1.16 - 10.0.1.31
  enable_shielded_nodes = true
  min_master_version    = "1.24"
  network               = google_compute_network.gke_network.self_link
  subnetwork            = google_compute_subnetwork.gke_subnet.self_link
  release_channel {
    channel = "UNSPECIFIED"
  }
  master_authorized_networks_config {
  }
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_ipv4_cidr_block = "10.2.0.0/21"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "10.3.0.0/28" # 10.1.0.1 - 10.1.0.15
  }
  depends_on = [google_project_service.enable_container_service]
}


resource "google_container_node_pool" "gke_node_pool" {
  project    = var.project
  name       = "gke-node-pool"
  location   = "asia-northeast1"
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "n1-standard-1"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.container_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [google_container_cluster.gke_cluster]
}

resource "google_compute_instance" "bastion" {
  project      = var.project
  name         = "bastion"
  machine_type = "n2-standard-2"
  zone         = "asia-northeast1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork_project = var.project
    network            = google_compute_network.gke_network.name
    subnetwork         = google_compute_subnetwork.gke_subnet.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<EOF
#!/bin/bash
sudo apt update
sudo apt install google-cloud-sdk-gke-gcloud-auth-plugin
gcloud components install kubectl
EOF

  metadata = {
    enable-oslogin = "true" # OS Login を有効化
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.container_sa.email
    scopes = ["cloud-platform"]
  }
  lifecycle {
    ignore_changes = [
      metadata_startup_script
    ]
  }
}

# resource "google_iap_web_backend_service_iam_member" "gke_accessible_members" {
#   project             = var.project
#   web_backend_service = ""
#   role                = "roles/iap.httpsResourceAccessor"
#   member              = "user:${var.accessible_email}"
# }
