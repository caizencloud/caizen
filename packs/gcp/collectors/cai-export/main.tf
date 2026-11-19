locals {
  scope_type = split("/", var.scope)[0]
  scope_id   = split("/", var.scope)[1]
}

resource "google_project_service" "this" {
  for_each = toset([
    "cloudasset.googleapis.com",
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
  description         = "Exports Cloud Asset Inventory snapshots of ${var.scope} to gs://${var.bucket}/raw/gcp-cai-*/"
  service_account     = google_service_account.collector.id
  source_contents     = file("${path.module}/workflow.yaml")
  call_log_level      = "LOG_ERRORS_ONLY"
  deletion_protection = false

  user_env_vars = {
    SCOPE                = var.scope
    BUCKET               = var.bucket
    CONTENT_TYPES        = join(",", var.content_types)
    POLL_TIMEOUT_SECONDS = tostring(var.poll_timeout_seconds)
    COLLECTOR_VERSION    = var.collector_version
  }

  depends_on = [google_project_service.this]
}
