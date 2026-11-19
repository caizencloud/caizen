variable "project" {
  description = "Project that runs the collector"
  type        = string
}

variable "region" {
  description = "Region for the Workflow and the Cloud Scheduler job"
  type        = string
}

variable "bucket" {
  description = "Caizen data bucket. The collector writes raw/cisa-kev/, raw/first-epss/, and tmp/kev-epss/."
  type        = string
}

variable "kev_url" {
  description = "CISA KEV catalog. The cisa.gov copy ignores Range requests, so the default is CISA's GitHub repo."
  type        = string
  default     = "https://raw.githubusercontent.com/cisagov/kev-data/main/known_exploited_vulnerabilities.json"
}

variable "epss_url" {
  description = "FIRST EPSS scores. This URL redirects to the dated daily file."
  type        = string
  default     = "https://epss.empiricalsecurity.com/epss_scores-current.csv.gz"
}

variable "chunk_bytes" {
  description = "Bytes per Range request. Workflows limits one string to 256 KB and all variables to 512 KB."
  type        = number
  default     = 240000
}

variable "schedule" {
  description = "Cron schedule, in UTC"
  type        = string
  default     = "0 7 * * *"
}

variable "collector_version" {
  description = "Version recorded in each _meta.json"
  type        = string
  default     = "0.1.0"
}

variable "name" {
  description = "Name of the Workflow and Cloud Scheduler job"
  type        = string
  default     = "kev-epss"
}
