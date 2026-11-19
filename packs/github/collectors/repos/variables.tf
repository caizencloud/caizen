variable "project" {
  description = "Project that runs the collector and holds the token secret"
  type        = string
}

variable "region" {
  description = "Region for the Workflow and the Cloud Scheduler job"
  type        = string
}

variable "bucket" {
  description = "Caizen data bucket. The collector writes under raw/github-api/."
  type        = string
}

variable "org" {
  description = "GitHub organization to collect"
  type        = string
}

variable "page_size" {
  description = "Items per GitHub API page. Workflows limits variables to 512 KB in total."
  type        = number
  default     = 30
}

variable "schedule" {
  description = "Cron schedule, in UTC"
  type        = string
  default     = "0 8 * * *"
}

variable "collector_version" {
  description = "Version recorded in each _meta.json"
  type        = string
  default     = "0.1.0"
}

variable "name" {
  description = "Name of the Workflow, Cloud Scheduler job, and token secret prefix"
  type        = string
  default     = "github-repos"
}
