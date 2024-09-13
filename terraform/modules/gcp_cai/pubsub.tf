// Pubsub topic for storage notifications
resource "google_pubsub_topic" "gcp_cai_topic" {
  project = var.project_id
  name    = "${var.module_name}-${var.name_prefix}-topic"
  labels  = var.labels

  message_retention_duration = "86400s"
}

// GCS notification to pubsub topic
resource "google_storage_notification" "gcp_cai_notification" {
  bucket = var.ingest_bucket_name
  topic  = google_pubsub_topic.gcp_cai_topic.id

  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE"]
}

// Pubsub subscription to trigger the function
resource "google_pubsub_subscription" "gcp_cai_subscription" {
  project = var.project_id
  name    = "${var.module_name}-${var.name_prefix}-subscription"
  topic   = google_pubsub_topic.gcp_cai_topic.name

  ack_deadline_seconds       = 600
  message_retention_duration = "86400s"

  filter = "(attributes.eventType = \"OBJECT_FINALIZE\") AND (attributes.bucketId = \"${var.ingest_bucket_name}\") AND (hasPrefix(attributes.objectId, \"${var.module_name}/\"))"

  push_config {
    push_endpoint = "https://${local.gcp_cai_function_name}-${data.google_project.project.number}.${var.location}.run.app"
    oidc_token {
      service_account_email = google_service_account.pushsub_sa.email
    }
  }
}
