---
title: Attack Paths
weight: 1
---

An attack path is a sequence of steps that leads from an entry point, such as a public endpoint, to a valuable target, such as an admin role or a sensitive dataset.

## Example

The following path is common in GCP.

1. A Cloud Run service allows unauthenticated requests from the internet.
2. The service's container image has a remote code execution CVE.
3. The service runs as a service account, and code in the container can request that account's token from the metadata server.
4. The service account has `storage.objectViewer` on a bucket that holds customer data.

Most teams receive these conditions as separate findings from different tools. A vulnerability scanner reports the CVE, a CSPM reports the public service, and an access review reports the IAM grant. Caizen combines them into one path from the internet to the customer data.

## Concrete and abstract graphs

Caizen maintains two related graphs.

The concrete graph contains the resources in your environment and the relationships between them. This includes projects, service accounts, Cloud Run services, buckets, firewall rules, container images, and repositories.

The abstract graph assigns each resource one or more types, such as compute, identity, credentials, storage, or data, and connects those types with attack path edges. Equivalent conditions on different clouds map to the same abstract edge. A public Cloud Run service and a public EC2 instance both produce an edge from internet to compute. Path finding and scoring use only the abstract graph, so they work the same way for every cloud provider.

Each abstract edge keeps a reference to the concrete resources that support it. Every edge can be traced back to the specific configuration that creates it.

## Capability requirements

Each edge type defines what an attacker must already have in order to use it, and what it provides.

| Edge type | Requires | Provides |
|---|---|---|
| Network access | | Ability to reach the resource |
| Code execution | | A foothold on the resource |
| Credential access | A foothold | A credential |
| Data access | A credential | Access to storage |
| Privilege escalation | A credential | Administrative control |

A path must meet these requirements at every step. Network access to a service does not provide that service's credentials, so a path cannot go from network access to credential access without code execution in between.

## Latent paths

A latent path is a path that is missing one edge. For example, a staging service might run the same vulnerable image as production but be blocked from the internet by a firewall rule. Caizen tracks latent paths and flags a path for agents as soon as a configuration change completes it.

## Data sources

| Source | Data |
|---|---|
| GCP Cloud Asset Inventory | Resources and IAM policies |
| Container Analysis | Vulnerability occurrences, and build provenance that links each image to its source repository and commit |
| GitHub | Repository settings and access controls |

Collectors retrieve this data on a schedule. See [Architecture](../../architecture/) for details.
