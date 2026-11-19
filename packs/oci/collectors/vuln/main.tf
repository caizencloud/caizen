resource "google_project_service" "this" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "containeranalysis.googleapis.com",
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
  description         = "Collects image facts and Artifact Analysis occurrences for given digests and their base images"
  service_account     = google_service_account.collector.id
  source_contents     = file("${path.module}/workflow.yaml")
  call_log_level      = "LOG_ERRORS_ONLY"
  deletion_protection = false

  user_env_vars = {
    BUCKET            = var.bucket
    REGION            = var.region
    REGISTRY_PROJECTS = join(",", var.registry_projects)
    PAGE_SIZE         = tostring(var.page_size)
    COLLECTOR_VERSION = var.collector_version
  }

  depends_on = [google_project_service.this]
}
