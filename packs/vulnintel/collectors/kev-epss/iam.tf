# The Workflow's identity. It creates objects under its two raw/ prefixes
# and its tmp/ prefix. Compose reads the chunks, so it can also read tmp/.
resource "google_service_account" "collector" {
  project      = var.project
  account_id   = var.name == "kev-epss" ? "kev-epss-sa" : "${var.name}-sa"
  display_name = "KEV and EPSS collector"
  description  = "Downloads the CISA KEV catalog and FIRST EPSS scores"
}

locals {
  objects = "projects/_/buckets/${var.bucket}/objects"
}

resource "google_storage_bucket_iam_member" "writer" {
  bucket = var.bucket
  role   = "roles/storage.objectCreator"
  member = google_service_account.collector.member

  condition {
    title       = "kev-epss prefixes"
    description = "Create objects under raw/cisa-kev, raw/first-epss, and tmp/kev-epss only"
    expression  = "resource.name.startsWith(\"${local.objects}/raw/cisa-kev/\") || resource.name.startsWith(\"${local.objects}/raw/first-epss/\") || resource.name.startsWith(\"${local.objects}/tmp/kev-epss/\")"
  }
}

resource "google_storage_bucket_iam_member" "tmp_reader" {
  bucket = var.bucket
  role   = "roles/storage.objectViewer"
  member = google_service_account.collector.member

  condition {
    title       = "kev-epss tmp prefix"
    description = "Read chunks under tmp/kev-epss for compose"
    expression  = "resource.name.startsWith(\"${local.objects}/tmp/kev-epss/\")"
  }
}

resource "google_project_iam_member" "log_writer" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.collector.member
}

resource "google_service_account" "scheduler" {
  project      = var.project
  account_id   = var.name == "kev-epss" ? "kev-epss-scheduler-sa" : "${var.name}-sched-sa"
  display_name = "KEV and EPSS scheduler"
  description  = "Starts the ${var.name} Workflow on schedule"
}

# The google provider has no Workflow-level IAM resource.
resource "google_project_iam_member" "scheduler_invoker" {
  project = var.project
  role    = "roles/workflows.invoker"
  member  = google_service_account.scheduler.member
}
