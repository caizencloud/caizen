---
title: Caizen
layout: hextra-home
params:
  width: wide
---

{{< hextra/hero-container image="img/caizen-logo-dark.png" imageWidth="300" imageHeight="239" imageTitle="Caizen" >}}

<div class="hx:mt-6 hx:mb-6">
{{< hextra/hero-headline >}}
  Harness the security superpowers&nbsp;<br class="hx:sm:block hx:hidden" />of your cloud asset inventory
{{< /hextra/hero-headline >}}
</div>

<div class="hx:mb-12">
{{< hextra/hero-subtitle >}}
  Caizen builds an attack graph from your cloud asset inventory and keeps it current as your environment changes.
{{< /hextra/hero-subtitle >}}
</div>

<div class="hx:mb-6">
{{< hextra/hero-button text="Read the docs" link="docs/" >}}
</div>

{{< /hextra/hero-container >}}

<div class="hx:mt-6"></div>

{{< hextra/feature-grid cols=3 >}}
  {{< hextra/feature-card
    icon="map"
    title="Live Attack Path Mapping"
    link="docs/concepts/attack-paths/"
    subtitle="The attack graph updates as your cloud configuration changes."
    style="background: radial-gradient(ellipse at 50% 80%, rgba(72, 58, 113, 0.18), hsla(0, 0%, 100%, 0));" >}}
  {{< hextra/feature-card
    icon="collection"
    title="Covers the Entire Stack"
    link="docs/concepts/attack-paths/"
    subtitle="Paths can span cloud configuration, IAM, container images, and source repositories."
    style="background: radial-gradient(ellipse at 50% 80%, rgba(111, 117, 124, 0.18), hsla(0, 0%, 100%, 0));" >}}
  {{< hextra/feature-card
    icon="filter"
    title="Dramatically Reduces Noise"
    link="docs/concepts/scoring/"
    subtitle="Findings are ranked by whether an attacker can reach them and what they lead to."
    style="background: radial-gradient(ellipse at 50% 80%, rgba(32, 34, 37, 0.15), hsla(0, 0%, 100%, 0));" >}}
  {{< hextra/feature-card
    icon="shield-check"
    title="Continuous Agent (Re)verification"
    link="docs/concepts/verification/"
    subtitle="Agents re-check uncertain and outdated edges, starting with the highest-value ones." >}}
  {{< hextra/feature-card
    icon="sort-descending"
    title="Efficient Remediation Priority"
    link="docs/concepts/remediation/"
    subtitle="Fixes are ranked by how many attack paths each one closes." >}}
  {{< hextra/feature-card
    icon="code"
    title="Generate Pull Request Fixes"
    link="docs/concepts/remediation/#pull-requests"
    subtitle="Agents open pull requests against the repositories that own each fix." >}}
{{< /hextra/feature-grid >}}
