# Caizen platform

Terraform module that deploys the Caizen platform into one project. It has no provider configuration, backend, or environment values. Each organization calls it from its own Terraform.

The module currently creates only the data bucket.

| Input | Description |
|---|---|
| `project` | Project that runs Caizen and holds its data |
| `region` | Region for regional resources |

| Output | Description |
|---|---|
| `data_bucket` | Name of the data bucket, `<project>-caizen-data` |
