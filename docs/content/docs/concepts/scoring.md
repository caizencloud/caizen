---
title: Scoring
weight: 2
---

Caizen scores attack paths. A path's score depends on the value of the target it reaches and the confidence of each step along the way.

## Value

Each target has a value. An organization admin role has a higher value than a project role, and a project role has a higher value than read access to a log bucket.

A path's value is the highest value among the targets it reaches. Caizen does not add values together, because that would give longer paths higher scores only because they pass through more targets.

## Confidence

Each edge has two confidence values.

| Value | Meaning |
|---|---|
| Existence | The probability that the edge exists |
| Traversal | The probability that an attacker who reaches the edge can use it |

An IAM binding read from the policy API has an existence confidence close to 1. A CVE reported by a scanner can have lower existence and traversal confidence.

## Path score

```
score = value × product over all hops of (existence × traversal)
```

Each hop contributes a factor of 1 or less, so a longer path scores lower unless every hop is highly certain.

In measured examples, most of the uncertainty is in the first hop. One path scored 0.965 × 1.0 × 0.995 × 0.999. The initial access step carried almost all of the uncertainty, and the IAM and metadata server steps that followed were close to certain.

## Effect on prioritization

Severity-based tools rank a critical CVE above a medium CVE regardless of context. In Caizen, a critical CVE on a service that cannot be reached produces a low-scoring path. A medium CVE on a public service with an over-privileged service account can produce a high-scoring path. Agents use these scores to decide which paths to work on first.

## Unknowns

Caizen also scores missing data. An image running in production that has never been scanned appears as an unknown, ranked by the value an attacker could reach through it. Caizen does not treat it as free of vulnerabilities.
