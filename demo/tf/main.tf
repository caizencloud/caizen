provider "google" {
  project = "ln-prod-web"
  region  = "us-central1"
}

// Service Account
resource "google_service_account" "api" {
  project      = "ln-prod-web"
  account_id   = "api-sa"
  display_name = "Cloud Run Service Account"
}

// SA Connects to SQL
resource "google_project_iam_member" "sql" {
  project = "ln-prod-web"
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.api.email}"
}
// SA is Editor
resource "google_project_iam_member" "editor" {
  project = "ln-prod-web"
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.api.email}"
}


// Cloud Run Service
resource "google_cloud_run_v2_service" "api" {
  name     = "api"
  location = "us-central1"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.api.email
    containers {
      image = "us-central1-docker.pkg.dev/ln-prod-automation/docker/api:1.1.2"
    }
  }
}

// Make Cloud Run Public
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_cloud_run_v2_service.api.project
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
