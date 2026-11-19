variable "project" {
  description = "Project that runs the collector"
  type        = string
}

variable "region" {
  description = "Region for the Workflow and of the Artifact Registry repos to search for base images"
  type        = string
}

variable "bucket" {
  description = "Caizen data bucket. The collector writes under raw/oci-*/ and raw/gcp-aa-*/."
  type        = string
}

variable "registry_projects" {
  description = "Projects whose Artifact Registry images and Artifact Analysis occurrences the collector reads"
  type        = list(string)
}

variable "page_size" {
  description = "Occurrences per page and per part object. Workflows limits variables to 512 KB in total, so keep this small."
  type        = number
  default     = 20
}

variable "collector_version" {
  description = "Version recorded in each _meta.json"
  type        = string
  default     = "0.1.0"
}

variable "name" {
  description = "Name of the Workflow"
  type        = string
  default     = "oci-vuln"
}
