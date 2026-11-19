# The Workflow's identity. It reads images and occurrences in the registry
# projects and creates objects under raw/oci-* and raw/gcp-aa-* only.
resource "google_service_account" "collector" {
  project      = var.project
  account_id   = var.name == "oci-vuln" ? "oci-vuln-sa" : "${var.name}-sa"
  display_name = "OCI image collector"
  description  = "Collects image facts and Artifact Analysis occurrences"
}

resource "google_project_iam_member" "registry_reader" {
  for_each = toset(var.registry_projects)

  project = each.value
  role    = "roles/artifactregistry.reader"
  member  = google_service_account.collector.member
}

resource "google_project_iam_member" "occurrences_viewer" {
  for_each = toset(var.registry_projects)

  project = each.value
  role    = "roles/containeranalysis.occurrences.viewer"
  member  = google_service_account.collector.member
}

resource "google_storage_bucket_iam_member" "raw_writer" {
  bucket = var.bucket
  role   = "roles/storage.objectCreator"
  member = google_service_account.collector.member

  condition {
    title       = "oci-vuln raw prefixes"
    description = "Create objects under raw/oci-* and raw/gcp-aa-* only"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.bucket}/objects/raw/oci-\") || resource.name.startsWith(\"projects/_/buckets/${var.bucket}/objects/raw/gcp-aa-\")"
  }
}

resource "google_project_iam_member" "log_writer" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = google_service_account.collector.member
}
