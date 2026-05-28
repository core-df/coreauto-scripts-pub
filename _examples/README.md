# Examples

Sample scripts showing how Core Auto step authors combine libraries from **coreauto-scripts-pub**.

| Language | Path | Coverage |
|----------|------|----------|
| **Python** | [Python/](Python/README.md) | Step + ingress (reference) |
| **Go** | [Go/](Go/README.md) | Step + ingress |
| **Shell** | [Shell/](Shell/README.md) | Step + ingress |
| **Node** | [Node/](Node/README.md) | Step + ingress |
| **Java** | [Java/](Java/README.md) | Step + ingress |
| **Kotlin** | [Kotlin/](Kotlin/README.md) | Step + ingress |
| **Scala** | [Scala/](Scala/README.md) | Step + ingress |
| **DotNet** | [DotNet/](DotNet/README.md) | Step + ingress |
| **Rust** | [Rust/](Rust/README.md) | Step + ingress |
| **Ruby** | [Ruby/](Ruby/README.md) | Step + ingress |
| **PHP** | [PHP/](PHP/README.md) | Step + ingress |
| **Perl** | [Perl/](Perl/README.md) | Step + ingress |
| **Swift** | [Swift/](Swift/README.md) | Step only |
| **Dart** | [Dart/](Dart/README.md) | Step only |
| **R** | [R/](R/README.md) | Step only |
| **Lua** | [Lua/](Lua/README.md) | Step only |
| **C** | [C/](C/README.md) | Step only |
| **COBOL** | [COBOL/](COBOL/README.md) | Step driver (Shell) |

Copy an example into your worker image or reference this repo on the library path for your language. Set only the environment variables for integrations you actually use — optional backends are skipped when not configured.

Reference implementation: [Python/full_integration_step.py](Python/full_integration_step.py).

## License

Copyright Core DF. Licensed under the [Apache License, Version 2.0](../LICENSE).
