# !!! Change the bucket name first
# gcloud storage buckets create gs://caizen-tfstate/ --location nam4 --uniform-bucket-level-access
# gcloud storage buckets update gs://caizen-tfstate/ --versioning --update-labels=owner=caizen
# terraform init
# terraform plan
# terraform apply

terraform {
  required_version = ">= 1.5.0"
  backend "gcs" {
    bucket = "caizen-tfstate"
    prefix = "caizen"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.2"
    }
  }
}

module "caizen_core" {
  source = "./modules/caizen_core"

  project_id  = "caizen-export"
  location    = "us-central1"
  name_prefix = "caizen"
}

module "cai_org" {
  source = "./modules/gcp_cai"

  project_id         = module.caizen_core.project_id
  location           = module.caizen_core.location
  name_prefix        = module.caizen_core.name_prefix
  ingest_bucket_name = module.caizen_core.ingest_bucket_name

  target_type = "organization"
  target_id   = "684587186245"
  schedule    = "50 */12 * * *"
}
