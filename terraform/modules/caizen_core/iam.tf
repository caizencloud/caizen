// Service Account for the CAIZEN VM
resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-vm"
  display_name = "CAIZEN VM Service Account"
}

// Grant the project SA the ability to use pubsub and token creator
data "google_project" "project" {
  project_id = var.project_id
}
resource "google_project_iam_member" "eventarc_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
resource "google_project_iam_member" "eventarc_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}
