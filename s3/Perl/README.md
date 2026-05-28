# s3 — Perl

See [Python](../Python/README.md) for API reference. Uses **AWS CLI** (`aws` on PATH).

```perl
use lib 'lib';
use S3client;
S3client::Init();
S3client::GetObject('path/key.txt');
```

Apache License 2.0.
