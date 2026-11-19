# cai-export collector

Terraform module that exports Cloud Asset Inventory snapshots to the Caizen data bucket. A Cloud Scheduler job starts a Workflow. The Workflow runs one `exportAssets` call per content type, all at the same `readTime`, and polls each one until it finishes. There is no container.

## Output

Each content type is a feed: `gcp-cai-resource`, `gcp-cai-iam-policy`, and `gcp-cai-org-policy`.

```
raw/<feed>/ingest_dt=<arrival date>/run=<readTime>/data/<ASSET_TYPE>/<shard>
raw/<feed>/ingest_dt=<arrival date>/run=<readTime>/_meta.json
raw/<feed>/ingest_dt=<arrival date>/run=<readTime>/_SUCCESS
```

`ingest_dt` is the UTC date the execution started. `run` is the export's `readTime`. `_SUCCESS` is written last. A feed whose export fails gets no `_SUCCESS`, and the execution fails after the other feeds finish.

`_meta.json` holds the feed, `read_time`, scope, content type, asset types, operation name, execution ID, collector version, and the exact list of exported objects.

## Running it

| Action | Command |
|---|---|
| Run now | `gcloud workflows run cai-export --location=<region>` |
| Backfill | `gcloud workflows run cai-export --location=<region> --data='{"read_time":"2026-11-10T06:00:00Z"}'` |

Cloud Asset Inventory accepts read times up to 35 days in the past.

## Inputs

| Input | Default | Description |
|---|---|---|
| `project` | | Project that runs the collector |
| `region` | | Region for the Workflow and the scheduler job |
| `bucket` | | Caizen data bucket |
| `scope` | | `organizations/<id>`, `folders/<id>`, or `projects/<id>` |
| `content_types` | `RESOURCE`, `IAM_POLICY`, `ORG_POLICY` | Content types to export |
| `schedule` | `0 6 * * *` | Cron schedule, UTC |
| `poll_timeout_seconds` | `1800` | How long to wait for each export |
| `collector_version` | `0.1.0` | Recorded in `_meta.json` |
| `name` | `cai-export` | Name of the Workflow and scheduler job |

## Identities

| Service account | Grants |
|---|---|
| `cai-export-sa` | `roles/cloudasset.viewer` on the scope. `roles/storage.objectCreator` on the bucket, limited to `raw/gcp-cai-*`. `roles/logging.logWriter` on the project. |
| `cai-export-scheduler-sa` | `roles/workflows.invoker` on the project |
