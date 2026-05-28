# cawbs — Perl client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Modules

| Module | Use case |
|--------|----------|
| **`lib/Cawbs.pm`** | Real-time steps |
| **`lib/Cawbsbatch.pm`** | Batch: auth + keystore |

## Prerequisites

- **Perl 5**
- **`LWP::UserAgent`** and **`JSON`** (CPAN)

```shell
cpan LWP::UserAgent JSON
```

## Usage

```perl
use lib 'lib';
use Cawbs;

my $result = Cawbs::Init();
die "$result->{error}\n" unless $result->{status_code} == 200;

my $event = Cawbs::GetEventPayload();
Cawbs::PutStepPayload({ status => 'ok' });
```

Functions return hashrefs with `status_code`, `error`, `payload`, and `answer` keys.

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
