# The Workflow's identity. It creates objects under raw/gcp-iam-role and
# tmp/iam-roles. Compose reads the chunks, so it can also read tmp/iam-roles.
# Listing predefined roles needs no IAM grant, and the source is public.
resource "google_service_account" "collector" {
  project      = var.project
  account_id   = "${var.name}-sa"
  display_name = "IAM roles collector"
  description  = "Downloads the predefined GCP IAM roles and their permissions"
}

locals {
  objects = "projects/_/buckets/${var.bucket}/objects"
}

resource "google_storage_bucket_iam_member" "writer" {
  bucket = var.bucket
  role   = "roles/storage.objectCreator"
  member = google_service_account.collector.member

  condition {
    title       = "iam-roles prefixes"
    description = "Create objects under raw/gcp-iam-role and tmp/iam-roles only"
    expression  = "resource.name.startsWith(\"${local.objects}/raw/gcp-iam-role/\") || resource.name.startsWith(\"${local.objects}/tmp/iam-roles/\")"
  }
}

resource "google_storage_bucket_iam_member" "tmp_reader" {
  bucket = var.bucket
  role   = "roles/storage.objectViewer"
  member = google_service_account.collector.member

  condition {
    title       = "iam-roles tmp prefix"
    description = "Read chunks under tmp/iam-roles for compose"
    expression  = "resource.name.startsWith(\"${local.objects}/tmp/iam-roles/\")"
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
  display_name = "IAM roles scheduler"
  description  = "Starts the ${var.name} Workflow on schedule"
}

# The google provider has no Workflow-level IAM resource.
resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project
  role    = "roles/workflows.invoker"
  member  = google_service_account.scheduler.member
}
