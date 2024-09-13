
locals {
  input_data = {
    "content_type" : var.target_content_type,
    "max_retries" : var.workflow_max_retries,
    "output_bucket" : var.ingest_bucket_name,
    "output_prefix" : var.module_name,
    "sleep_seconds" : var.workflow_sleep_seconds,
    "target_id" : var.target_id,
    "target_type" : var.target_type
  }
}

resource "google_cloud_scheduler_job" "workflow_trigger" {
  project     = var.project_id
  name        = "${var.module_name}-${var.target_type}s-${var.target_id}"
  description = "Caizen ${var.module_name}-${var.target_type}s-${var.target_id} workflow trigger"
  region      = var.location

  schedule  = var.schedule
  time_zone = "Etc/UTC"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/workflows/${google_workflows_workflow.gcp_cai.name}/executions"

    # Pass input data to the workflow
    body = base64encode(<<-EOM
        { "argument": ${jsonencode(jsonencode((local.input_data)))}}
    EOM
    )

    oauth_token {
      service_account_email = google_service_account.scheduler_sa.email
    }
  }
}
