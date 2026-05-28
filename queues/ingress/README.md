# ingress — queue to Collector bridge

Consume from a queue backend and submit Core Auto real-time events via **cawbsingress** (`TriggerEvent`, `RunBridge`).

Matches [Python](Python/README.md). Run as a long-lived bridge process, not inside a step.

## Languages

| Language | Path |
|----------|------|
| Python | [`Python/`](Python/) |
| Go | [`Go/`](Go/) |
| Shell | [`Shell/`](Shell/) |
| Node.js | [`Node/`](Node/) |
| Java | [`Java/`](Java/) |
| Kotlin | [`Kotlin/`](Kotlin/) |
| Scala | [`Scala/`](Scala/) |
| .NET | [`DotNet/`](DotNet/) |
| Rust | [`Rust/`](Rust/) |
| Ruby | [`Ruby/`](Ruby/) |
| PHP | [`PHP/`](PHP/) |
| Perl | [`Perl/`](Perl/) |

## Build

Java/Kotlin require **cawbs** on the classpath (`mvn install` in `cawbs/Java` first).

```shell
cd queues/ingress/Java && mvn -q compile
cd queues/ingress/DotNet && dotnet build
```

## Environment

| Variable | Purpose |
|----------|---------|
| `CA_EVENT_NAME` | Core Auto event definition to trigger |
| `CA_EVENT_SOURCE` | Optional event source |
| `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` | Collector auth (via cawbsingress) |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
