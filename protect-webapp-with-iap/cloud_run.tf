resource "google_cloud_run_service" "hello_cloudrun" {
  name     = "hello-cloudrun"
  location = "asia-northeast1"
  project  = var.project

  template {
    spec {
      containers {
        image = "asia-northeast1-docker.pkg.dev/${var.project}/hello-cloudrun/hello-cloudrun"
      }
    }
  }
  autogenerate_revision_name = true

  traffic {
    percent         = 100
    latest_revision = true
  }
  depends_on = [
    google_project_service.enable_cloudrun_service
  ]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.hello_cloudrun.location
  project  = google_cloud_run_service.hello_cloudrun.project
  service  = google_cloud_run_service.hello_cloudrun.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
