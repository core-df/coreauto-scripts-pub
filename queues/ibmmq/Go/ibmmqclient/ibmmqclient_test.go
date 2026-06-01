package ibmmqclient

import "testing"

func TestInit_MissingHost(t *testing.T) {
	t.Setenv("MQ_HOST", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("MQ_HOST", "mq.local")
	t.Setenv("MQ_QUEUE_MANAGER", "QM1")
	t.Setenv("MQ_QUEUE", "DEV.QUEUE")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
