<div align="center">
  <a href="https://caizen.cloud">
    <img src="docs/static/img/caizen-logo-dark.png" alt="Logo" width="160" height="160">
  </a>

  <h3 align="center"><a href="https://caizen.cloud">Caizen</a></h3>

  <p align="center">
    Harness the security superpowers of your cloud asset inventory.
  </p>
</div>

## Overview

Caizen is an agent-first attack path analysis system for cloud environments. It gathers inventory and findings into one graph, and agents keep that graph current and use it to choose and apply fixes, as described in the [documentation](https://caizen.cloud/docs/).

## This Repo

| Directory | Contents |
|---|---|
| `app/` | The Caizen service, written in Go, and its end-to-end tests |
| `packs/` | Rules, feed definitions, and collectors, grouped by the system they talk to (GCP, GitHub, container registries) |
| `terraform/` | Terraform for the platform, its environments, and the test org used as reference infrastructure to build and test collectors |
| `docs/` | The docs site at [caizen.cloud](https://caizen.cloud), built with Hugo |

## Background

Caizen began as a fwd:cloudsec 2024 talk. The code from the talk is at the [`fwdcloudsec-2024`](https://github.com/caizencloud/caizen/tree/refs/tags/fwdcloudsec-2024) tag.

- [fwd:cloudsec 2024 talk](https://youtu.be/Bltr5Bn2-70)
- [Talk slides](https://docs.google.com/presentation/d/1TotkfJIeCdl8ftN4i4OlQnZA5Hs4K-03EQoSYbWwdBc)

## License

Licensed under the [Functional Source License, Version 1.1, ALv2 Future License](LICENSE) (FSL-1.1-ALv2). Each release becomes available under the Apache License 2.0 two years after it is published.

Code up to and including the `fwdcloudsec-2024` tag remains under the Apache License 2.0.

## Contact

Brad Geesaman - [LinkedIn](https://linkedin.com/in/bradgeesaman)
