// VPC Network
resource "google_compute_network" "vpc" {
  project = var.project_id
  name    = "${var.name_prefix}-vpc"

  auto_create_subnetworks = false
}
// VPC Subnet
resource "google_compute_subnetwork" "subnet" {
  project = var.project_id
  name    = "${var.name_prefix}-${var.location}-subnet"
  region  = var.location
  network = google_compute_network.vpc.self_link

  private_ip_google_access = true
  ip_cidr_range            = var.vpc_subnet_ip_cidr_range
}
