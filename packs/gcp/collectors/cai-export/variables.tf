variable "project" {
  description = "Project that runs the collector"
  type        = string
}

variable "region" {
  description = "Region for the Workflow and the Cloud Scheduler job"
  type        = string
}

variable "bucket" {
  description = "Caizen data bucket. The collector writes under raw/gcp-cai-*/."
  type        = string
}

variable "scope" {
  description = "Export scope: organizations/<id>, folders/<id>, or projects/<id>"
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders|projects)/[0-9a-z-]+$", var.scope))
    error_message = "scope must be organizations/<id>, folders/<id>, or projects/<id>."
  }
}

variable "content_types" {
  description = "Cloud Asset Inventory content types to export. Each one is its own feed."
  type        = list(string)
  default     = ["RESOURCE", "IAM_POLICY", "ORG_POLICY"]
}

variable "schedule" {
  description = "Cron schedule for the export, in UTC"
  type        = string
  default     = "0 6 * * *"
}

variable "poll_timeout_seconds" {
  description = "How long to wait for each export to finish"
  type        = number
  default     = 1800
}

variable "collector_version" {
  description = "Version recorded in each _meta.json"
  type        = string
  default     = "0.1.0"
}

variable "name" {
  description = "Name of the Workflow and Cloud Scheduler job"
  type        = string
  default     = "cai-export"
}
