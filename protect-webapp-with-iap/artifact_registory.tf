resource "google_artifact_registry_repository" "hello-cloudrun-repo" {
  project       = var.project
  location      = "asia-northeast1"
  repository_id = "hello-cloudrun"
  description   = "example docker repository"
  format        = "DOCKER"
  depends_on = [
    google_project_service.enable_artifact_registry
  ]
}
