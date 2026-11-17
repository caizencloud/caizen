---
title: Verification
weight: 3
---

Every fact in Caizen has a source, an observation time, and a confidence that decreases over time. Agents re-check facts in an order set by uncertainty and value.

## Provenance

Caizen records one of three provenance tiers for each fact.

| Tier | Source | Example |
|---|---|---|
| Config | Read from a cloud API | An IAM binding or a firewall rule |
| Agent | Observed by an agent | A port that responded to a probe |
| Static | Reported by a scanner | A CVE matched to an image |

Caizen weights each tier differently and stores the tier with every fact, so an agent can see how each fact was learned. Static findings have the highest false positive rate.

## Decay

Confidence in an edge decays toward unknown over time. An old observation that an edge existed becomes uncertain. Caizen never treats it as evidence that the edge is gone.

Each edge type has its own decay rate. Network reachability decays quickly. A CVE on a specific image digest decays slowly. When a configuration change affects a resource, confidence in the edges that depend on that resource drops immediately.

## Scheduling

Caizen orders re-checks by uncertainty multiplied by the value at stake. Each agent has a budget, and the highest-priority checks run first.

Caizen can resolve most uncertainty cheaply. In one test, re-reading configuration confirmed 22 of 27 edges, and those edges held 13% of the total uncertainty. The remaining 87% was in five edges that passive probes, such as banner grabs and HTTP fingerprints, could resolve.

## Agents

Each agent holds credentials for a single domain, such as network probing, source code access, or a container registry. Agents have no direct access to storage. They read the graph through the service API and write their results as evidence, which Caizen loads the same way as collector data.

Caizen treats active testing beyond passive checks as authorized penetration testing and enforces its scope and limits.

## Admission checks

Caizen validates agent results before accepting them. Each result must be well formed, reference existing resources, describe an edge that is valid between the resource types involved, and come from an agent that is permitted to make that kind of claim.

When an agent finds nothing, Caizen marks the edge unverified. Caizen marks an edge as removed only when it observes a reason, such as a deleted firewall rule.

When agents disagree, Caizen keeps the more conservative value and schedules an immediate re-check.
