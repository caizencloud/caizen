output "workflow" {
  description = "Full resource name of the Workflow"
  value       = google_workflows_workflow.this.id
}

output "feeds" {
  description = "Feed IDs this collector writes"
  value       = ["gcp-iam-role"]
}
