variable "project_id" {
  description = "The project ID to deploy the resources"
  type        = string
}
variable "location" {
  description = "The location to deploy the resources"
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
variable "ingest_bucket_name" {
  description = "The name of the GCS bucket for all Caizen data ingest"
  type        = string
}
variable "module_name" {
  description = "The name of the module"
  type        = string
  default     = "gcp-cai"
}
variable "labels" {
  description = "The labels to apply to all resources"
  type        = map(string)
  default = {
    "owner" = "caizen"
  }
}
variable "workflow_call_log_level" {
  description = "The log level for the workflow"
  type        = string
  default     = "LOG_ERRORS_ONLY"
  validation {
    condition     = can(regex("^(CALL_LOG_LEVEL_UNSPECIFIED|LOG_ALL_CALLS|LOG_ERRORS_ONLY|LOG_NONE)$", var.workflow_call_log_level))
    error_message = "workflow_call_log_level must be one of CALL_LOG_LEVEL_UNSPECIFIED, LOG_ALL_CALLS, LOG_ERRORS_ONLY, or LOG_NONE"
  }
}
variable "schedule" {
  description = "The schedule for the workflow"
  type        = string
  default     = "*/6 * * * *" # Every 10 minutes
  validation {
    condition     = can(regex("^\\S+ \\S+ \\S+ \\S+ \\S+$", var.schedule))
    error_message = "schedule must be in the format 'minute hour day month weekday'"
  }
}
variable "workflow_max_retries" {
  description = "The maximum number of retries for the workflow"
  type        = number
  default     = 30
  validation {
    condition     = can(regex("^[0-9]+$", var.workflow_max_retries))
    error_message = "workflow_max_retries must be a number"
  }
}
variable "workflow_sleep_seconds" {
  description = "The number of seconds to sleep between retries"
  type        = number
  default     = 30
  validation {
    condition     = can(regex("^[0-9]+$", var.workflow_sleep_seconds))
    error_message = "workflow_sleep_seconds must be a number"
  }
}

variable "target_type" {
  description = "The type of the target resource"
  type        = string
  validation {
    condition     = can(regex("^(organization|folder|project)$", var.target_type))
    error_message = "target_type must be one of organization, folder, or project"
  }
}
variable "target_id" {
  description = "The ID of the target resource"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{10,12}$", var.target_id))
    error_message = "target_id must be a 10-12 digit number"
  }
}
variable "target_content_type" {
  description = "The content type for the export"
  type        = string
  default     = "resource"
  validation {
    condition     = can(regex("^(resource|iam_policy|org_policy|os_inventory)$", var.target_content_type))
    error_message = "content_type must be one of resource, iam_policy, org_policy, or os_inventory"
  }
}
variable "target_roles" {
  description = "The roles to grant to get the CAI data"
  type        = list(string)
  default     = ["roles/cloudasset.viewer"]
}

variable "project_roles" {
  description = "The roles to grant to the SA in the local project"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}
