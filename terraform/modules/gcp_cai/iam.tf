// Target specific GCP SA
resource "google_service_account" "cai_sa" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-c-${substr(var.target_type, 0, 1)}-${var.target_id}"
  display_name = "CAI Export - ${var.name_prefix}-${var.target_type}-${var.target_id}"
  description  = "SA to fetch CAI data"
}

// If target_type is organization
resource "google_organization_iam_member" "cai_org" {
  for_each = var.target_type == "organization" ? toset(var.target_roles) : []
  org_id   = var.target_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cai_sa.email}"
}

// If target_type is folder
resource "google_folder_iam_member" "cai_folder" {
  for_each = var.target_type == "folder" ? toset(var.target_roles) : []
  folder   = "folders/${var.target_id}"
  role     = each.value
  member   = "serviceAccount:${google_service_account.cai_sa.email}"
}

// If target_type is project
resource "google_project_iam_member" "cai_project" {
  for_each = var.target_type == "project" ? toset(var.target_roles) : []
  project  = "projects/${var.target_id}"
  role     = each.value
  member   = "serviceAccount:${google_service_account.cai_sa.email}"
}

// Grant the SA local project roles
resource "google_project_iam_member" "cai_local" {
  project  = var.project_id
  for_each = toset(var.project_roles)
  role     = each.value
  member   = "serviceAccount:${google_service_account.cai_sa.email}"
}

locals {
  // The name of the GCS bucket for all CAI data ingest
  target_path = "${var.module_name}/${var.target_type}s/${var.target_id}"
}
// Grant the SA the ability to read/write to the GCS bucket
resource "google_storage_bucket_iam_member" "ingest_bucket" {
  bucket = var.ingest_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cai_sa.email}"

  condition {
    title       = "CAI Export prefix"
    description = "Grant the SA the ability to read/write to the GCS bucket"
    expression  = "resource.name.startsWith('projects/_/buckets/${var.ingest_bucket_name}/objects/${local.target_path}/')"
  }
}

// Scheduler SA and permissions
resource "google_service_account" "scheduler_sa" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-s-${substr(var.target_type, 0, 1)}-${var.target_id}"
  display_name = "Scheduler - ${var.name_prefix}-${var.target_type}-${var.target_id}"
  description  = "SA to trigger the workflow on a schedule"
}
resource "google_project_iam_member" "schedulder_invoke_workflow" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

// Allow GCS to send pubsub messages
data "google_storage_project_service_account" "default" {
  project = var.project_id
}
resource "google_project_iam_member" "gcs_pubsub_publishing" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.default.email_address}"
}

// Pubsub Push subscription SA to trigger the function
resource "google_service_account" "pushsub_sa" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-ps-${substr(var.target_type, 0, 1)}-${var.target_id}"
  display_name = "Push Sub - ${var.name_prefix}-${var.target_type}-${var.target_id}"
  description  = "SA to trigger the function on object finalization"
}
resource "google_project_iam_member" "pushsub_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.pushsub_sa.email}"
}

// Function SA
resource "google_service_account" "gcp_cai_function" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-gcp-cai-func"
  display_name = "GCP CAI Function SA"
}
data "google_project" "project" {
  project_id = var.project_id
}

// Cloudbuild permissions to deploy the function
locals {
  roles = [
    "roles/cloudfunctions.developer",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
  ]
}
resource "google_project_iam_member" "gcp_cai_cloudbuild" {
  project  = var.project_id
  for_each = toset(local.roles)
  role     = each.value
  member   = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
resource "google_project_iam_member" "cloudbuild" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}
