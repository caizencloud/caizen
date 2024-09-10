// Main data_ingest bucket for collecting all data
resource "google_storage_bucket" "data_ingest" {
  project  = var.project_id
  location = var.location

  name   = "${var.name_prefix}-${var.ingest_bucket_name}"
  labels = var.labels

  storage_class               = var.ingest_bucket_storage_class
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  // Object versioning to prevent accidental overwrites
  versioning {
    enabled = true
  }

  // Move to next storage class if not the latest version
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = var.ingest_next_storage_class
    }
    condition {
      num_newer_versions = 1
      with_state         = "ARCHIVED"
    }
  }

  // Delete all objects after N days if they aren't the latest version
  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age                = var.ingest_bucket_name_delete_age_days
      num_newer_versions = 2
      with_state         = "ARCHIVED"
    }
  }

  // Delete all objects after a year regardless
  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 365
    }
  }

  // Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}
