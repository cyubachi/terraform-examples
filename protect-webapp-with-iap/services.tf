# enable API

# IAP
resource "google_project_service" "enable_iap_service" {
  project = var.project
  service = "iap.googleapis.com"
}
