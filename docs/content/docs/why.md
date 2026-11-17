---
title: Why Caizen
weight: 2
---

Caizen drives agent-first security analysis with a context graph built by and for agents to act on. The usual tool-oriented approach, where each security tool reports its own findings and people connect them by hand, is inefficient and wasteful. It has proven to fall short in large environments, especially against agent-driven attacks.

## The problem

Security tools do not have the context needed to support decisions. Each tool knows only its own findings and nothing about the findings of other tools. Many tools also work from snapshots that go out of date.

To act on a finding, a person looks at it in isolation and then finds the business context by hand: who owns the resource, how critical it is, which environment it runs in, and which regulatory requirements apply. This work is slow, and almost every security team struggles with this in some form.

## The approach

Most security workflows start with a finding and then go looking for the details around it. Caizen works the other way around. It gathers all security-relevant context ahead of time, and agents keep the graph in sync with the environment. When an agent has to decide which fix to apply first, a few graph queries give it the ownership, environment, and exposure details it needs to choose and act.

Keeping the graph current and re-checking it against reality is tedious, and the amount of work grows quickly with the size of the environment. Targeted agents do this work as well. They keep the graph up to date and keep an audit trail of every check and change.

When a decision needs context that Caizen does not have, the solution is a new collector.

## Example

A VM is reachable from the internet, has a CVE, and has an IAM role attached. An agent queries the graph for the VM's environment, its owner, and what the IAM role can access, and chooses an action right away.

| Environment | Action |
|---|---|
| Sandbox | Close the port directly with the AWS CLI. |
| Production | Open a pull request for the DevOps team that updates the base container image, or open a ticket for the security team to reduce the IAM role's permissions. |

Agents on those teams can handle the pull requests and tickets in turn.

## Who it is for

Caizen is for cloud security engineers, security team leads, and the platform and infrastructure teams who ship fixes. Each organization deploys Caizen in its own environment.
