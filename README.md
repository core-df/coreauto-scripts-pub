# coreauto-scripts-pub

Public **libraries and snippets** for [Core Auto](https://coreauto.coredf.com/description) step scripts — reusable code you import or copy into batch and real-time workloads.

Core Auto orchestrates jobs through a metadata model and executes each step as a script or CLI on workers and agents. This repository holds helper libraries that step authors use inside those scripts: talking to the Collector, integrating with external systems, and sharing common patterns.

This repo is **not** the Core Auto runtime. Agents, workers, and PostgreSQL orchestration live in [**coreauto-mngr-pub**](https://github.com/core-df/coreauto-mngr-pub) (separate project).

## Contents

| Library | Description |
|---------|-------------|
| [**cawbs**](cawbs/README.md) | Client for the [Core Auto Collector](https://coreauto.coredf.com/resources) REST API — authentication, real-time payloads, keystore, batch, and ingress variants. |
| [**queues**](queues/README.md) | Messaging — produce from steps; [ingress bridge](queues/ingress/Python/README.md) consumes and triggers events via **cawbsingress**. |
| [**http**](http/README.md) | Generic REST/HTTP client. |
| [**files**](files/README.md) | Local file and SFTP transfer. |
| [**notify**](notify/README.md) | Slack, Teams, email, PagerDuty. |
| [**s3**](s3/README.md) | S3-compatible object get/put/list. |
| [**transform**](transform/README.md) | JSON, CSV, and XML utilities. |
| [**Examples**](_examples/README.md) | End-to-end sample step + ingress bridge combining multiple libraries. |

## Language implementations

Snippet libraries follow the same multi-language layout as [**cawbs**](cawbs/README.md): Python, Go, Shell, Node.js, Java, Kotlin, Scala, .NET, Rust, Ruby, PHP, Perl, R, Lua, Dart, Swift, and (for **http** / **transform** only) COBOL. See each library README for the exact folders and per-language build notes.

| Library | README |
|---------|--------|
| cawbs | [cawbs/README.md](cawbs/README.md) |
| http | [http/README.md](http/README.md) |
| transform | [transform/README.md](transform/README.md) |
| files | [files/README.md](files/README.md) |
| notify | [notify/README.md](notify/README.md) |
| s3 | [s3/README.md](s3/README.md) |
| queues | [queues/README.md](queues/README.md) |

## Using a library

Each top-level folder has its own README with prerequisites, environment variables, and examples. In general:

1. Add the library to your step script environment (`PYTHONPATH`, module path, or copy the files next to your script).
2. Rely on environment variables set by the Core Auto worker (and documented per library).
3. Keep credentials out of scripts — use Collector keystore or platform-managed secrets where applicable.

See the [Core Auto resources](https://coreauto.coredf.com/resources) site for product documentation and API reference.

## License

Copyright Core DF. Licensed under the [Apache License, Version 2.0](LICENSE).
