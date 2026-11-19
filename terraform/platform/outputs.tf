output "data_bucket" {
  description = "Name of the Caizen data bucket"
  value       = google_storage_bucket.data.name
}
