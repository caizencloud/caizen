output "workflow" {
  description = "Full resource name of the Workflow"
  value       = google_workflows_workflow.this.id
}

output "collector_service_account" {
  description = "Email of the Workflow's service account"
  value       = google_service_account.collector.email
}

output "feeds" {
  description = "Feed IDs this collector writes, one per content type"
  value       = [for ct in var.content_types : "gcp-cai-${replace(lower(ct), "_", "-")}"]
}
