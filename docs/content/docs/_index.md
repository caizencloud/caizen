---
title: Overview
weight: 1
---

Caizen is an agent-first attack path analysis system for cloud environments. It collects inventory and findings from cloud APIs, container scanners, and source repositories, builds a graph of the ways an attacker could move between resources, and ranks the resulting paths. Agents query the graph for the context they need to choose a fix and then apply it.

Each edge in the graph records where it came from, when it was observed, and how confident Caizen is in it. Confidence decreases as data ages, and Caizen schedules agents to re-check edges before they become unreliable.

```mermaid
flowchart LR
  C[Collectors] -->|inventory and findings| B[(Bucket)]
  A[Agents] -->|evidence| B
  B --> S[Caizen]
  S -->|re-check requests| A
  S -->|context| R[Remediation agents]
  R --> F[Changes, pull requests, tickets]
```

## Sections

{{< cards >}}
  {{< card link="why/" title="Why Caizen" icon="light-bulb" subtitle="The problem Caizen addresses and its approach." >}}
  {{< card link="concepts/attack-paths/" title="Attack Paths" icon="map" subtitle="How resources and permissions become attack paths." >}}
  {{< card link="concepts/scoring/" title="Scoring" icon="filter" subtitle="How paths are ranked." >}}
  {{< card link="concepts/verification/" title="Verification" icon="shield-check" subtitle="How facts are sourced, aged, and re-checked." >}}
  {{< card link="concepts/remediation/" title="Remediation" icon="sort-descending" subtitle="How fixes are prioritized and delivered." >}}
  {{< card link="architecture/" title="Architecture" icon="server" subtitle="Components and data flow." >}}
  {{< card link="history/" title="History" icon="video-camera" subtitle="The 2024 talk and prototype." >}}
{{< /cards >}}
