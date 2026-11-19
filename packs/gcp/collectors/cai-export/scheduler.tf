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
