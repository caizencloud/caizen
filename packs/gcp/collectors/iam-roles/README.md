# iam-roles collector

Terraform module that downloads every predefined and basic GCP IAM role, with its `includedPermissions`, into the Caizen data bucket once a day. It is a single Workflow with no container. Caizen's rules match on permissions, so they need each role's permission list.

## How it works

The source is `gcp_roles_cai.json` in `darkbitio/gcp-iam-role-permissions`. That repo's GitHub Action runs `gcloud iam roles describe` for every predefined role twice a day and commits an NDJSON file with one role per line, about 8 MB. The Workflow:

1. Resolves `source_ref` to a commit SHA. It asks the commits endpoint for the SHA alone, because the full response lists every changed file and can exceed Workflows memory.
2. Reads the commit time from `/git/commits/<sha>`.
3. Reads the file's total size at that SHA with a one-byte `Range` request.
4. Downloads the file in `Range` requests of `chunk_bytes` and writes each chunk to `tmp/iam-roles/<run>/`. A URL at a fixed commit cannot change between chunks.
5. Joins the chunks with the Cloud Storage `compose` call, in steps when there are more than 32.
6. Fails if the joined object's size differs from the source's size.
7. Writes `_meta.json`, then `_SUCCESS` last.

The Workflow cannot call the IAM API itself: `roles/owner` alone is about 528 KB of JSON, and Workflows limits all variables in an execution to 512 KB. A source that needs no third-party repo would be a Cloud Run job paging `iam.googleapis.com/v1/roles?view=FULL`. The feed stays the same either way.

The GitHub API calls are unauthenticated, which allows 60 requests an hour per IP. A run makes two.

A lifecycle rule from the platform module deletes `tmp/` objects after one day. The chunk, compose, and upload subworkflows are copied from the `kev-epss` collector, because Workflows cannot share subworkflows across files.

## Output

| Feed | Object |
|---|---|
| `gcp-iam-role` | `raw/gcp-iam-role/ingest_dt=<date>/run=<time>/data/gcp_roles_cai.json` |

The feed is of kind `snapshot`. `_meta.json` holds the source repo, ref, commit SHA, commit time (`committed_at`), source URL, size, and chunk count. Custom roles are not in the source; Cloud Asset Inventory exports them as `iam.googleapis.com/Role`.

## Inputs

| Input | Default | Description |
|---|---|---|
| `project` | | Project that runs the collector |
| `region` | | Region for the Workflow and scheduler job |
| `bucket` | | Caizen data bucket |
| `source_repo` | `darkbitio/gcp-iam-role-permissions` | GitHub repo with the role file |
| `source_path` | `gcp_roles_cai.json` | Role file in the repo |
| `source_ref` | `main` | Branch or tag, resolved to a SHA on each run |
| `chunk_bytes` | `240000` | Bytes per `Range` request |
| `schedule` | `0 9 * * *` | Cron schedule, UTC |
| `collector_version` | `0.1.0` | Recorded in `_meta.json` |
| `name` | `iam-roles` | Name of the Workflow and scheduler job |

## Identities

| Service account | Grants |
|---|---|
| `iam-roles-sa` | `roles/storage.objectCreator` on `raw/gcp-iam-role` and `tmp/iam-roles`. `roles/storage.objectViewer` on `tmp/iam-roles`, which compose needs. `roles/logging.logWriter`. |
| `iam-roles-sched-sa` | `roles/workflows.invoker` on the project |
