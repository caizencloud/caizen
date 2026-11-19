# The Workflow's identity. It reads the token secret and creates objects
# under raw/github-api/ only.
resource "google_service_account" "collector" {
  project      = var.project
  account_id   = "${var.name}-sa"
  display_name = "GitHub collector"
  description  = "Collects the ${var.org} GitHub organization"
}

resource "google_secret_manager_secret_iam_member" "token_reader" {
  project   = var.project
  secret_id = google_secret_manager_secret.token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.collector.member
}

resource "google_storage_bucket_iam_member" "raw_writer" {
  bucket = var.bucket
  role   = "roles/storage.objectCreator"
  member = google_service_account.collector.member

  condition {
    title       = "github-api raw prefix"
    description = "Create objects under raw/github-api only"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.bucket}/objects/raw/github-api/\")"
  }
}

resource "google_project_iam_member" "log_writer" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.collector.member
}

resource "google_service_account" "scheduler" {
  project      = var.project
  account_id   = "${var.name}-sched-sa"
  display_name = "GitHub collector scheduler"
  description  = "Starts the ${var.name} Workflow on schedule"
}

# The google provider has no Workflow-level IAM resource.
resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project
  role    = "roles/workflows.invoker"
  member  = google_service_account.scheduler.member
}
