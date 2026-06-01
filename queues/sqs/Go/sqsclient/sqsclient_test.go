package sqsclient

import "testing"

func TestInit_MissingQueue(t *testing.T) {
	t.Setenv("AWS_ACCESS_KEY_ID", "k")
	t.Setenv("SQS_QUEUE_URL", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("AWS_ACCESS_KEY_ID", "k")
	t.Setenv("SQS_QUEUE_URL", "https://sqs/queue")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
