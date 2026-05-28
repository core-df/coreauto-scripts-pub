# queues — ingress (Ruby)

Queue ingress bridge for Core Auto. See [Python](../Python/README.md).

```ruby
require_relative 'ingress'
require_relative '../../kafka/Ruby/lib/kafkaclient'

Ingress.RunBridge(-> { Kafkaclient.Consume('orders', max_messages: 10) })
```

Apache License 2.0.
