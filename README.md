# coreauto-scripts-pub

Public **libraries and snippets** for [Core Auto](https://coreauto.coredf.com/description) step scripts — reusable code you import or copy into batch and real-time workloads.

Core Auto orchestrates jobs through a metadata model and executes each step as a script or CLI on workers and agents. This repository holds helper libraries that step authors use inside those scripts: talking to the Collector, integrating with external systems, and sharing common patterns.

This repo is **not** the Core Auto runtime. Agents, workers, and PostgreSQL orchestration live in [**coreauto-mngr-pub**](https://github.com/core-df/coreauto-mngr-pub) (separate project).

## Contents

| Library | Description |
|---------|-------------|
| [**cawbs**](cawbs/README.md) | Client for the [Core Auto Collector](https://coreauto.coredf.com/resources) REST API — authentication, real-time payloads, and keystore access. Implementations in Python, Go, Shell, C, and other languages under [`cawbs/`](cawbs/). |

Additional libraries and snippets may be added here over time as step-script needs grow.

## Using a library

Each top-level folder has its own README with prerequisites, environment variables, and examples. In general:

1. Add the library to your step script environment (`PYTHONPATH`, module path, or copy the files next to your script).
2. Rely on environment variables set by the Core Auto worker (and documented per library).
3. Keep credentials out of scripts — use Collector keystore or platform-managed secrets where applicable.

See the [Core Auto resources](https://coreauto.coredf.com/resources) site for product documentation and API reference.

## License

Copyright Core DF. Licensed under the [Apache License, Version 2.0](LICENSE).
