# github-repos collector

Terraform module that collects one GitHub organization into the Caizen data bucket once a day. It is a single Workflow with no container.

## What it collects

| Scope | Endpoints |
|---|---|
| Organization | The org and its settings, owners and members, outside collaborators, app installations, Actions permissions, webhooks, and the token's own user |
| Each team | Maintainers, members, and repo access |
| Each repo | Details, collaborators with permissions, teams, default branch protection, rulesets, webhooks, deploy keys, Actions permissions, `CODEOWNERS` in its three possible locations, and each file in `.github/workflows/` |

## Output

Feed `github-api`, kind `snapshot`. Each line is one API response page:

```
{"endpoint": "...", "params": {...}, "page": 1, "status": 200, "body": ...}
```

The batch time is `started` in `_meta.json`. Lines carry no timestamp of their own, so an unchanged page produces an identical line on every run.

Each page is its own part object: `raw/github-api/ingest_dt=<date>/run=<time>/part-<n>.ndjson`, followed by `_meta.json` and `_SUCCESS`.

A 403 or 404 that means "not available on this plan" or "not configured" is recorded with its status, because it is evidence. On a Free org, branch protection and rulesets on private repos return 403. A 401, rate limiting, or a 5xx after retries fails the run with no markers.

## Token

The module creates an empty Secret Manager secret, `github-token`. Create a fine-grained personal access token with resource owner set to the organization, access to all repositories, and these read-only permissions:

| Level | Permissions |
|---|---|
| Repository | Metadata, Administration, Contents, Actions, Webhooks |
| Organization | Members, Administration, Webhooks |

Then add it, so the value never enters Terraform state:

```
gcloud secrets versions add github-token --project=<project> --data-file=-
```

Fine-grained tokens expire. Renew the token before its expiry date.

## Inputs

| Input | Default | Description |
|---|---|---|
| `project` | | Project that runs the collector and holds the secret |
| `region` | | Region for the Workflow and scheduler job |
| `bucket` | | Caizen data bucket |
| `org` | | GitHub organization |
| `page_size` | `30` | Items per API page |
| `schedule` | `0 8 * * *` | Cron schedule, UTC |
| `collector_version` | `0.1.0` | Recorded in `_meta.json` |
| `name` | `github-repos` | Name of the Workflow and scheduler job |

## Identities

| Service account | Grants |
|---|---|
| `github-repos-sa` | `roles/secretmanager.secretAccessor` on the token secret. `roles/storage.objectCreator` on `raw/github-api`. `roles/logging.logWriter`. |
| `github-repos-sched-sa` | `roles/workflows.invoker` on the project |
