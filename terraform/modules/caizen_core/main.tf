// Enable required APIs
resource "google_project_service" "enabled_apis" {
  for_each = toset(var.enabled_apis)
  project  = var.project_id
  service  = each.value

  // Prevent removal on destroy
  disable_on_destroy = true
}
