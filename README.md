<a id="readme-top"></a>


<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/caizencloud/caizen">
    <img src="docs/img/caizen-logo-dark.png" alt="Logo" width="160" height="160">
  </a>

  <h3 align="center"><a href="https://caizen.cloud">CAIZEN</a></h3>

  <p align="center">
    Harness the security superpowers of your GCP Cloud Asset Inventory.
    <br />
    <br />
    <a href="https://youtu.be/Bltr5Bn2-70">View fwd:cloudsec 2024 Talk</a>
    ·
    <a href="https://docs.google.com/presentation/d/1TotkfJIeCdl8ftN4i4OlQnZA5Hs4K-03EQoSYbWwdBc">View Talk Slides</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li><a href="#getting-started">Getting Started</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

If we map our cloud resources in full like this:

<img src="docs/img/resources.png" width="640">

Then we can derive Attack Paths like this:

<img src="docs/img/attackpaths.png" width="640">

And score them like this:

<img src="docs/img/pathscores.png" width="640">

Which enables us to measure risky combinations in our cloud configurations by modeling attacker behavior to resource goals/sub-goals using [MITRE ATT&CK® Framework](https://attack.mitre.org/) [Tactics, Techniques, and Procedures](https://attack.mitre.org/resources/) or "TTPs".

As a proof-of-concept, a companion tool was created named [Psychiac](https://github.com/caizencloud/psychiac) to demonstrate the value of evaluating attack paths on proposed changes by Terraform _before apply_ in a CI pipeline.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

* [Memgraph](https://memgraph.com/) - A Bolt/Neo4j compatible Graph DB running in memory
* [FastAPI](https://fastapi.tiangolo.com/) - a modern, fast (high-performance), web framework for building APIs with Python based on standard Python type hints.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

The project is undergoing active development to go from PoC to real-time resource graph.  Stay tuned.


<!-- ROADMAP -->
## Roadmap

- [x] Proof of value
- [ ] Periodic ingest and parsing of all GCP CAI resources
- [ ] Real-time ingest and parsing of CAI resource updates

<p align="right">(<a href="#readme-top">back to top</a>)</p>




<!-- LICENSE -->
## License

Distributed under the Apache 2.0 License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

This project is not quite ready to accept external contributions.  In the meantime, feel free to contact me about your specific needs.

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- CONTACT -->
## Contact

Brad Geesaman - [@bradgeesaman](https://twitter.com/bradgeesaman)

Project Link: [https://github.com/caizencloud/caizen](https://github.com/caizencloud/caizen)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

Here are a list of related resources:

* [Psychiac](https://github.com/caizencloud/psychiac) - A proof-of-concept CI companion tool for CAIZEN to perform attack path analysis before apply.
* [Google Cloud Asset Inventory](https://cloud.google.com/asset-inventory/docs/overview) - A full cloud resource inventory service.
* [MITRE ATT&CK® Framework](https://attack.mitre.org/) - A security framework for modeling attacker behaviors.
* [OpenCSPM](https://github.com/OpenCSPM/opencspm) - Prior work in this space using Ruby and RedisGraph with my coworker [joshlarsen](https://github.com/joshlarsen)
* [Cartography](https://github.com/lyft/cartography) - Original inspiration for OpenCSPM and now CAIZEN came from Cartography by Lyft. Cartography consolidates infrastructure assets and the relationships between them in an intuitive graph view.

<p align="right">(<a href="#readme-top">back to top</a>)</p>
