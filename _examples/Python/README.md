# Full integration example (Python)

One **real-time step** and one **ingress bridge** that together exercise every Python snippet library in this repo.

## Scripts

| Script | Role | Libraries used |
|--------|------|----------------|
| [`full_integration_step.py`](full_integration_step.py) | Core Auto step (one-shot) | **cawbs**, **transform**, **files**, **http**, **s3**, **notify**, all **queue** producers |
| [`full_integration_ingress.py`](full_integration_ingress.py) | Long-lived bridge | **kafka** consume, **ingress**, **cawbsingress** |

## Setup

```shell
cd /path/to/coreauto-scripts-pub/_examples/Python
pip install -r requirements.txt
```

Scripts call [`lib_paths.py`](lib_paths.py) to add library folders to `PYTHONPATH` automatically (repo root = two levels up).

## Run the step (local smoke test)

Core Auto sets these on the worker; for local testing export manually:

```shell
export ENV=dev
export ACTIONID=1
export STEPNAME=EnrichOrder
export CA_ACCESS_CODE=your-code
export CA_WBS_URL=http://collector:9100

python3 full_integration_step.py
```

Optional integrations — set only what you use; others are skipped:

| Integration | Example variables |
|-------------|-------------------|
| Event input file | `EXAMPLE_CSV_PATH`, `EXAMPLE_XML_PATH` |
| Keystore | `EXAMPLE_KEYSTORE_KEYS=partner_api_key` |
| Partner HTTP | `PARTNER_API_URL`, `PARTNER_WEBHOOK_URL` |
| S3 | `AWS_*`, `S3_BUCKET`, `S3_CONFIG_PREFIX` |
| SFTP | `SFTP_HOST`, `SFTP_USER`, …, `EXAMPLE_SFTP_REMOTE` |
| Queues | per-backend vars (see each [`queues/`](../../queues/README.md) README) + `EXAMPLE_KAFKA_TOPIC`, `EXAMPLE_QUEUE_NAME`, `EXAMPLE_NATS_SUBJECT` |
| Notify | `SLACK_WEBHOOK_URL`, `TEAMS_WEBHOOK_URL`, `SMTP_*`, `PAGERDUTY_ROUTING_KEY` |

## Run the ingress bridge

```shell
export ENV=dev
export CA_ACCESS_CODE=your-code
export CA_WBS_URL=http://collector:9100
export CA_EVENT_NAME=OrderInbound
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
export EXAMPLE_KAFKA_TOPIC=orders.inbound

python3 full_integration_ingress.py
```

Each Kafka message triggers `POST /v1/rtevent`; Core Auto then runs the workflow containing `full_integration_step.py`.

## Flow

```
Partner → Kafka → full_integration_ingress.py → Collector (PostEvent)
                                                      ↓
                                            full_integration_step.py
                                                      ↓
                              transform / files / http / s3 / queues / notify
                                                      ↓
                                            cawbs.PutStepPayload
```

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
