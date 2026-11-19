# The Caizen data bucket holds all durable state: collector output under
# raw/ and everything the service derives from it. Each collector gets
# create-only access to its own raw/<feed>/ prefix.
#
# There is no retention lock. A retention policy applies to the whole
# bucket and cannot be removed once locked. Create-only IAM keeps
# collectors from rewriting raw/.
resource "google_storage_bucket" "data" {
  project                     = var.project
  name                        = "${var.project}-caizen-data"
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}
