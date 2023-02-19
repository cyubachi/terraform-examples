# enable API

# IAP
resource "google_project_service" "enable_iap_service" {
  project = var.project
  service = "iap.googleapis.com"
}

# Artifact Registry
resource "google_project_service" "enable_artifact_registry" {
  project = var.project
  service = "artifactregistry.googleapis.com"
}


# Cloud Run 
resource "google_project_service" "enable_cloudrun_service" {
  project = var.project
  service = "run.googleapis.com"
}

# Compute Engine
# Required to reserve load balancer ip address and create ssl certificate.
resource "google_project_service" "enable_compute_engine_service" {
  project = var.project
  service = "compute.googleapis.com"
}

# Cloud DNS
# Required to open console page.
resource "google_project_service" "enable_cloud_dns_service" {
  project = var.project
  service = "dns.googleapis.com"
}
