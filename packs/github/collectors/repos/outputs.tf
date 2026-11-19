output "workflow" {
  description = "Full resource name of the Workflow"
  value       = google_workflows_workflow.this.id
}

output "token_secret" {
  description = "Secret to add the GitHub token to"
  value       = google_secret_manager_secret.token.id
}

output "feeds" {
  description = "Feed IDs this collector writes"
  value       = ["github-api"]
}
