# The Workflow's identity. It reads inventory across the scope and creates
# objects under raw/gcp-cai-* only. objectCreator cannot overwrite or
# delete, so a run never rewrites earlier output.
resource "google_service_account" "collector" {
  project      = var.project
  account_id   = var.name == "cai-export" ? "cai-export-sa" : "${var.name}-sa"
  display_name = "CAI export collector"
  description  = "Exports Cloud Asset Inventory snapshots of ${var.scope}"
}

resource "google_organization_iam_member" "collector_viewer" {
  count = local.scope_type == "organizations" ? 1 : 0

  org_id = local.scope_id
  role   = "roles/cloudasset.viewer"
  member = google_service_account.collector.member
}

resource "google_folder_iam_member" "collector_viewer" {
  count = local.scope_type == "folders" ? 1 : 0

  folder = var.scope
  role   = "roles/cloudasset.viewer"
  member = google_service_account.collector.member
}

resource "google_project_iam_member" "collector_viewer" {
  count = local.scope_type == "projects" ? 1 : 0

  project = local.scope_id
  role    = "roles/cloudasset.viewer"
  member  = google_service_account.collector.member
}

resource "google_storage_bucket_iam_member" "collector_raw_writer" {
  bucket = var.bucket
  role   = "roles/storage.objectCreator"
  member = google_service_account.collector.member

  condition {
    title       = "cai-export raw prefixes"
    description = "Create objects under raw/gcp-cai-* only"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.bucket}/objects/raw/gcp-cai-\")"
  }
}

resource "google_project_iam_member" "collector_log_writer" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.collector.member
}

# Starts the Workflow on schedule. The google provider has no
# Workflow-level IAM resource, so the invoker grant is project-level.
resource "google_service_account" "scheduler" {
  project      = var.project
  account_id   = var.name == "cai-export" ? "cai-export-scheduler-sa" : "${var.name}-sched-sa"
  display_name = "CAI export scheduler"
  description  = "Starts the ${var.name} Workflow on schedule"
}

resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project
  role    = "roles/workflows.invoker"
  member  = google_service_account.scheduler.member
}
