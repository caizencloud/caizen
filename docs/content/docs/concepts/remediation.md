---
title: Remediation
weight: 4
---

Remediation agents use the graph to decide which fix to apply first and how to apply it.

## Choke edges

Many attack paths share edges. A single over-privileged service account can appear in a dozen paths. Caizen ranks each edge by the confidence-weighted value of the paths that pass through it. Removing a highly ranked edge closes every path that depends on it, so agents start with the highest-ranked edges.

## Choosing an action

An agent working on an edge queries the graph for the context of each resource involved, such as its environment, its owner, and the system that manages it. That context determines the action.

| Context | Action |
|---|---|
| Sandbox resource | Apply the change directly, for example by closing a port with the AWS CLI. |
| Resource managed in Terraform | Open a pull request against the Terraform repository. |
| Vulnerable container image | Open a pull request that updates the base image. Build provenance identifies the repository and commit that built the image. |
| Change that needs human review | Open a ticket for the team that owns the resource. |

Agents on the receiving teams can handle those pull requests and tickets in turn.

## Confirmation

After a fix ships, Caizen re-checks the affected edges. When Caizen confirms that an edge is closed, it also closes every path that depended on it. This produces an audit trail of which attack paths each change removed.
