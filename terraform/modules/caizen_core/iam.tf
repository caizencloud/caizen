// Service Account for the CAIZEN VM
resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-vm"
  display_name = "CAIZEN VM Service Account"
}
