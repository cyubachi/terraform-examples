resource "google_app_engine_application" "default" {
  project     = var.project
  location_id = "asia-northeast1"
  iap {
    enabled              = true
    oauth2_client_id     = var.iap_client_id
    oauth2_client_secret = var.iap_client_secret
  }
}

resource "google_iap_web_type_app_engine_iam_member" "member" {
  project = google_app_engine_application.default.project
  app_id  = google_app_engine_application.default.app_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = "user:${var.accessible_email}"
  depends_on = [
    google_project_service.enable_iap_service
  ]
}
