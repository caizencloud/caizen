variable "project" {
  description = "Project that runs the collector"
  type        = string
}

variable "region" {
  description = "Region for the Workflow and the Cloud Scheduler job"
  type        = string
}

variable "bucket" {
  description = "Caizen data bucket. The collector writes raw/gcp-iam-role/ and tmp/iam-roles/."
  type        = string
}

variable "source_repo" {
  description = "GitHub repo that publishes the role definitions"
  type        = string
  default     = "darkbitio/gcp-iam-role-permissions"
}

variable "source_path" {
  description = "NDJSON file in source_repo, one role per line"
  type        = string
  default     = "gcp_roles_cai.json"
}

variable "source_ref" {
  description = "Branch or tag of source_repo, resolved to a commit SHA on each run"
  type        = string
  default     = "main"
}

variable "chunk_bytes" {
  description = "Bytes per Range request. Workflows limits one string to 256 KB and all variables to 512 KB."
  type        = number
  default     = 240000
}

variable "schedule" {
  description = "Cron schedule, in UTC"
  type        = string
  default     = "0 9 * * *"
}

variable "collector_version" {
  description = "Version recorded in each _meta.json"
  type        = string
  default     = "0.1.0"
}

variable "name" {
  description = "Name of the Workflow and Cloud Scheduler job. Service account IDs derive from it, so keep it at 19 characters or fewer."
  type        = string
  default     = "iam-roles"
}
