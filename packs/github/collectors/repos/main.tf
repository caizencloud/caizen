resource "google_project_service" "this" {
  for_each = toset([
    "cloudscheduler.googleapis.com",
    "secretmanager.googleapis.com",
    "workflows.googleapis.com",
  ])

  project            = var.project
  service            = each.value
  disable_on_destroy = false
}

# An empty secret. Add the token yourself, so its value never enters
# Terraform state:
#   gcloud secrets versions add <secret> --project=<project> --data-file=-
resource "google_secret_manager_secret" "token" {
  project   = var.project
  secret_id = var.name == "github-repos" ? "github-token" : "${var.name}-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}

resource "google_workflows_workflow" "this" {
  project             = var.project
  region              = var.region
  name                = var.name
  description         = "Collects the ${var.org} GitHub organization into gs://${var.bucket}/raw/github-api/"
  service_account     = google_service_account.collector.id
  source_contents     = file("${path.module}/workflow.yaml")
  call_log_level      = "LOG_ERRORS_ONLY"
  deletion_protection = false

  user_env_vars = {
    ORG               = var.org
    BUCKET            = var.bucket
    TOKEN_SECRET      = "${google_secret_manager_secret.token.id}/versions/latest"
    PAGE_SIZE         = tostring(var.page_size)
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
