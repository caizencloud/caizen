# kev-epss collector

Terraform module that downloads the CISA Known Exploited Vulnerabilities (KEV) catalog and the FIRST EPSS scores into the Caizen data bucket once a day. It is a single Workflow with no container.

## How it works

Workflows limits one string to 256 KB and all variables in an execution to 512 KB, and both files are larger. For each file, the Workflow:

1. Resolves redirects. The EPSS URL redirects to the dated daily file, and the stored object takes that file's name.
2. Reads the size, ETag, and `Last-Modified` with a `HEAD` request.
3. Downloads the file in `Range` requests of `chunk_bytes` and writes each chunk to `tmp/kev-epss/<run>/<feed>/`.
4. Joins the chunks with the Cloud Storage `compose` call, in steps when there are more than 32.
5. Fails the feed if the joined object's size differs from the source's `Content-Length`.
6. Writes `_meta.json`, then `_SUCCESS` last.

A lifecycle rule from the platform module deletes `tmp/` objects after one day.

## Output

| Feed | Object |
|---|---|
| `cisa-kev` | `raw/cisa-kev/ingest_dt=<date>/run=<time>/data/known_exploited_vulnerabilities.json` |
| `first-epss` | `raw/first-epss/ingest_dt=<date>/run=<time>/data/epss_scores-<date>.csv.gz`, gzipped as published |

Both feeds are of kind `snapshot`. `_meta.json` holds the source and final URLs, ETag, `Last-Modified`, size, chunk count, and for KEV the `catalogVersion` and `dateReleased`.

The cisa.gov copy of the KEV catalog ignores `Range` requests, so the default source is CISA's GitHub repo, `cisagov/kev-data`.

## Inputs

| Input | Default | Description |
|---|---|---|
| `project` | | Project that runs the collector |
| `region` | | Region for the Workflow and scheduler job |
| `bucket` | | Caizen data bucket |
| `kev_url` | `cisagov/kev-data` raw URL | KEV source |
| `epss_url` | `epss_scores-current.csv.gz` | EPSS source |
| `chunk_bytes` | `240000` | Bytes per `Range` request |
| `schedule` | `0 7 * * *` | Cron schedule, UTC |
| `collector_version` | `0.1.0` | Recorded in `_meta.json` |
| `name` | `kev-epss` | Name of the Workflow and scheduler job |

## Identities

| Service account | Grants |
|---|---|
| `kev-epss-sa` | `roles/storage.objectCreator` on `raw/cisa-kev`, `raw/first-epss`, and `tmp/kev-epss`. `roles/storage.objectViewer` on `tmp/kev-epss`, which compose needs. `roles/logging.logWriter`. |
| `kev-epss-scheduler-sa` | `roles/workflows.invoker` on the project |
