resource "google_storage_bucket" "func_bucket" {
  project  = var.project_id
  name     = "${var.project_id}-gcf-source"
  location = var.location

  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
}

data "archive_file" "gcp_cai_function" {
  type        = "zip"
  output_path = "/tmp/gcp_cai-function.zip"
  source_dir  = "../caizen/gcp_cai_func/"
  excludes = [
    "*.terraform*",
    "*.git*",
    "*.DS_Store*",
    "*.pyc*",
    "__pycache__*",
    "*.lock",
    "*.toml",
    "*.zi*",
    "tests",
    "Makefile",
    "README.md"
  ]
}

resource "google_storage_bucket_object" "gcp_cai_function" {
  name   = "gcp_cai/source.zip"
  bucket = google_storage_bucket.func_bucket.name
  source = data.archive_file.gcp_cai_function.output_path
}

locals {
  gcp_cai_function_name = "${var.module_name}-${var.name_prefix}-function"
}
resource "google_cloudfunctions2_function" "gcp_cai_function" {
  project     = var.project_id
  name        = local.gcp_cai_function_name
  location    = var.location
  description = "GCP CAI Function"

  build_config {
    runtime     = "python311"
    entry_point = "main"
    source {
      storage_source {
        bucket = google_storage_bucket.func_bucket.name
        object = google_storage_bucket_object.gcp_cai_function.name
      }
    }
  }

  service_config {
    max_instance_count = 10
    available_memory   = "512M"
    timeout_seconds    = 540
    environment_variables = {
      CAIZEN_API_URL = "https://localhost:8080"
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.gcp_cai_function.email
  }

  depends_on = [google_storage_bucket_object.gcp_cai_function]
  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.gcp_cai_function
    ]
  }
}

