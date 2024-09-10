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
  ingest_bucket_name = "${var.name_prefix}-${var.ingest_bucket_name}"
  target_path        = "${var.module_name}/${var.target_type}s/${var.target_id}"
}
// Grant the SA the ability to read/write to the GCS bucket
resource "google_storage_bucket_iam_member" "ingest_bucket" {
  bucket = local.ingest_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cai_sa.email}"

  condition {
    title       = "CAI Export prefix"
    description = "Grant the SA the ability to read/write to the GCS bucket"
    expression  = "resource.name.startsWith('projects/_/buckets/${local.ingest_bucket_name}/objects/${local.target_path}/')"
  }
}

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

