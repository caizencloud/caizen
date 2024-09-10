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

  // Move to next storage class after N days
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = var.ingest_next_storage_class
    }
    condition {
      age = var.ingest_next_storage_class_age_days
    }
  }

  // Delete all objects after N days
  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age        = var.ingest_bucket_name_delete_age_days
      with_state = "ANY"
    }
  }

  // Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}
