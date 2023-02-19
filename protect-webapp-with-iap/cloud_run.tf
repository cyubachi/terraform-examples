resource "google_cloud_run_service" "hello_cloudrun" {
  name     = "hello-cloudrun"
  location = "asia-northeast1"
  project  = var.project

  template {
    spec {
      containers {
        image = "asia-northeast1-docker.pkg.dev/${var.project}/hello-cloudrun/hello-cloudrun:latest"
      }
    }
  }
  autogenerate_revision_name = true
  metadata {
    annotations = {
      "run.googleapis.com/ingress"      = "internal-and-cloud-load-balancing"
      "run.googleapis.com/operation-id" = ""
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
  lifecycle {
    ignore_changes = [
      metadata.0.annotations["run.googleapis.com/operation-id"]
    ]
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


# reserve load balancer ip address
resource "google_compute_global_address" "load_balancer_address" {
  project = var.project
  name    = "load-balancer-address"
  depends_on = [
    google_project_service.enable_compute_engine_service
  ]
}

# create load balancer ssl certificate
resource "google_compute_managed_ssl_certificate" "load_balancer_certificate" {
  project = var.project
  name    = "load-balancer-certificate"
  managed {
    domains = [var.cloud_run_domain]
  }
  depends_on = [
    google_project_service.enable_compute_engine_service
  ]
}

# create cloud run network endpoint group
resource "google_compute_region_network_endpoint_group" "cloud_run_network_endpoint_group" {
  project               = var.project
  name                  = "cloud-run-network-endpoint-group"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast1"
  cloud_run {
    service = google_cloud_run_service.hello_cloudrun.name
  }
}

# create cloud run backend service
resource "google_compute_backend_service" "cloud_run_backend_service" {
  project = var.project
  name    = "cloud-run-service-backend"

  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_network_endpoint_group.id
  }
  iap {
    oauth2_client_id     = var.iap_client_id
    oauth2_client_secret = var.iap_client_secret
  }
}

# no rule url map
resource "google_compute_url_map" "cloud_run_service_url_map" {
  project         = var.project
  name            = "cloud-run-service-urlmap"
  default_service = google_compute_backend_service.cloud_run_backend_service.id
}

resource "google_compute_target_https_proxy" "cloud_run_service_https_proxy" {
  project = var.project
  name    = "cloud-run-service-https-proxy"

  url_map = google_compute_url_map.cloud_run_service_url_map.id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.load_balancer_certificate.id
  ]
  depends_on = [
    google_compute_managed_ssl_certificate.load_balancer_certificate,
    google_compute_url_map.cloud_run_service_url_map
  ]
}

resource "google_compute_global_forwarding_rule" "cloud_run_service_forwarding_rule" {
  project = var.project
  name    = "cloud-run-service-load-balancer"

  target     = google_compute_target_https_proxy.cloud_run_service_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.load_balancer_address.address
  depends_on = [
    google_compute_target_https_proxy.cloud_run_service_https_proxy,
    google_compute_global_address.load_balancer_address
  ]
}


output "load_balancer_ip" {
  value = google_compute_global_address.load_balancer_address.address
}

resource "google_iap_web_backend_service_iam_member" "cloud_run_accessible_members" {
  project             = var.project
  web_backend_service = google_compute_backend_service.cloud_run_backend_service.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "user:${var.accessible_email}"
  depends_on = [
    google_compute_backend_service.cloud_run_backend_service
  ]
}
