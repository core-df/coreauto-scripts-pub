# notify — Perl

See [Python](../Python/README.md) for API reference.

```perl
use lib 'lib';
use Notifyclient;
Notifyclient::Slack('hello');
```

Requires: `LWP::UserAgent`, `JSON`. Email also needs `MIME::Lite`, `Net::SMTP`.

Apache License 2.0.
