# oci-vuln collector

Terraform module that collects container image facts and Google Artifact Analysis occurrences for a list of image digests, plus the base image of each one. It is a single Workflow with no container. Until the Caizen service exists, it runs only by hand.

## How it works

1. The Workflow lists every Docker image in the Artifact Registry repos of `registry_projects` in `region`, with each image's config `diff_ids`. These are the base candidates.
2. For each requested digest, it fetches the manifest and config as files from the Artifact Registry REST API. For an image index, it follows the `linux/amd64` entry. The base is the candidate whose `diff_ids` are the longest strict prefix of the digest's `diff_ids`.
3. For each requested digest and each base, it writes one `oci-image` line, then pages through the `VULNERABILITY`, `BUILD`, `DISCOVERY`, and `PACKAGE` occurrences and writes each page as one part object.
4. A failure for one digest is recorded in `_meta.json` and does not stop the others. A failed bucket write fails the execution with no markers.
5. For each feed, it writes `_meta.json`, then `_SUCCESS` last.

## Output

| Feed | One line per |
|---|---|
| `oci-image` | Digest: its roles, the digest it is the base of, its base, the index if any, the manifest, and the config |
| `gcp-aa-vulnerability` | `VULNERABILITY` occurrence, as returned by the API |
| `gcp-aa-build` | `BUILD` occurrence, which holds the build provenance |
| `gcp-aa-discovery` | `DISCOVERY` occurrence, which holds the scan status and continuous analysis state |
| `gcp-aa-package` | `PACKAGE` occurrence |

```
raw/<feed>/ingest_dt=<date>/run=<start time>/part-<first 12 hex of digest>-<page>.ndjson
raw/<feed>/ingest_dt=<date>/run=<start time>/_meta.json
raw/<feed>/ingest_dt=<date>/run=<start time>/_SUCCESS
```

All feeds are of kind `event`. A run covers only the digests it was given, so a missing digest was not requested.

## Running it

```
gcloud workflows run oci-vuln --location=<region> \
  --data='{"digests":["us-central1-docker.pkg.dev/<project>/<repo>/<image>@sha256:<hex>"]}'
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `project` | | Project that runs the collector |
| `region` | | Region of the Workflow and of the repos searched for bases |
| `bucket` | | Caizen data bucket |
| `registry_projects` | | Projects whose images and occurrences are read |
| `page_size` | `20` | Occurrences per page. Workflows limits variables to 512 KB in total. |
| `collector_version` | `0.1.0` | Recorded in `_meta.json` |
| `name` | `oci-vuln` | Name of the Workflow |

## Identity

`oci-vuln-sa` gets `roles/artifactregistry.reader` and `roles/containeranalysis.occurrences.viewer` on each registry project, `roles/storage.objectCreator` on the bucket limited to `raw/oci-*` and `raw/gcp-aa-*`, and `roles/logging.logWriter`.
