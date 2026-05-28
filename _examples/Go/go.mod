module github.com/core-df/coreauto-scripts-pub/_examples/Go

go 1.22

require (
	github.com/core-df/coreauto-scripts-pub/cawbs/Go v0.0.0
	github.com/core-df/coreauto-scripts-pub/files/Go v0.0.0
	github.com/core-df/coreauto-scripts-pub/transform/Go v0.0.0
	github.com/core-df/coreauto-scripts-pub/queues/kafka/Go v0.0.0
	github.com/core-df/coreauto-scripts-pub/queues/rabbit/Go v0.0.0
	github.com/core-df/coreauto-scripts-pub/queues/sqs/Go v0.0.0
	github.com/core-df/coreauto-scripts-pub/queues/redis/Go v0.0.0
	github.com/core-df/coreauto-scripts-pub/queues/ingress/Go v0.0.0
)

replace (
	github.com/core-df/coreauto-scripts-pub/cawbs/Go => ../../cawbs/Go
	github.com/core-df/coreauto-scripts-pub/files/Go => ../../files/Go
	github.com/core-df/coreauto-scripts-pub/transform/Go => ../../transform/Go
	github.com/core-df/coreauto-scripts-pub/queues/kafka/Go => ../../queues/kafka/Go
	github.com/core-df/coreauto-scripts-pub/queues/rabbit/Go => ../../queues/rabbit/Go
	github.com/core-df/coreauto-scripts-pub/queues/sqs/Go => ../../queues/sqs/Go
	github.com/core-df/coreauto-scripts-pub/queues/redis/Go => ../../queues/redis/Go
	github.com/core-df/coreauto-scripts-pub/queues/ingress/Go => ../../queues/ingress/Go
)
