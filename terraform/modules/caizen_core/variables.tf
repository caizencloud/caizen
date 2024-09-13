variable "project_id" {
  description = "The GCP project ID to deploy the resources to"
  type        = string
}

variable "location" {
  description = "The GCP region to deploy the resources to"
  type        = string
}

variable "name_prefix" {
  description = "The prefix to use for all resources"
  type        = string
  default     = "caizen"
  validation {
    condition     = can(regex("^\\p{L}.*$", var.name_prefix))
    error_message = "name_prefix must start with a letter"
  }
}
variable "labels" {
  description = "The labels to apply to all resources"
  type        = map(string)
  default = {
    "owner" = "caizen"
  }
}

variable "ingest_bucket_name" {
  description = "The name of the GCS bucket for all Caizen data ingest"
  type        = string
  default     = "data-ingest"
}
variable "ingest_bucket_storage_class" {
  description = "The storage class for the ingest bucket"
  type        = string
  default     = "STANDARD"
}
variable "ingest_next_storage_class" {
  description = "The storage class to transition objects to after the initial storage class"
  type        = string
  default     = "NEARLINE"
}
variable "ingest_next_storage_class_age_days" {
  description = "The age in days to transition the ingest bucket objects to the next storage class"
  type        = number
  default     = 7
}
variable "ingest_bucket_name_delete_age_days" {
  description = "The age in days to delete all ingest bucket objects"
  type        = number
  default     = 30
}

variable "enabled_apis" {
  description = "The list of APIs to enable for the project"
  type        = list(string)
  default = [
    "cloudasset.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "eventarc.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "workflows.googleapis.com",
  ]
}

variable "vpc_subnet_ip_cidr_range" {
  description = "The IP CIDR range for the VPC subnet"
  type        = string
  default     = "10.100.0.0/24"
}
