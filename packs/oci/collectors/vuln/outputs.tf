output "workflow" {
  description = "Full resource name of the Workflow"
  value       = google_workflows_workflow.this.id
}

output "collector_service_account" {
  description = "Email of the Workflow's service account"
  value       = google_service_account.collector.email
}

output "feeds" {
  description = "Feed IDs this collector writes"
  value       = ["oci-image", "gcp-aa-vulnerability", "gcp-aa-build", "gcp-aa-discovery", "gcp-aa-package"]
}
