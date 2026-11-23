resource "google_project_service" "this" {
  for_each = toset([
    "cloudscheduler.googleapis.com",
    "workflows.googleapis.com",
  ])

  project            = var.project
  service            = each.value
  disable_on_destroy = false
}

resource "google_workflows_workflow" "this" {
  project             = var.project
  region              = var.region
  name                = var.name
  description         = "Downloads the predefined GCP IAM roles to gs://${var.bucket}/raw/gcp-iam-role/"
  service_account     = google_service_account.collector.id
  source_contents     = file("${path.module}/workflow.yaml")
  call_log_level      = "LOG_ERRORS_ONLY"
  deletion_protection = false

  user_env_vars = {
    BUCKET            = var.bucket
    SOURCE_REPO       = var.source_repo
    SOURCE_PATH       = var.source_path
    SOURCE_REF        = var.source_ref
    CHUNK_BYTES       = tostring(var.chunk_bytes)
    COLLECTOR_VERSION = var.collector_version
  }

  depends_on = [google_project_service.this]
}

resource "google_cloud_scheduler_job" "this" {
  project     = var.project
  region      = var.region
  name        = var.name
  description = "Starts the ${var.name} Workflow"
  schedule    = var.schedule
  time_zone   = "Etc/UTC"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.this.id}/executions"
    body        = base64encode(jsonencode({ argument = jsonencode({}) }))

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }

  depends_on = [google_project_iam_member.scheduler_invoker]
}
