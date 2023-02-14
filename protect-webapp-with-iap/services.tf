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
