package kafkaclient

import "testing"

func TestInit_Missing(t *testing.T) {
	t.Setenv("KAFKA_BOOTSTRAP_SERVERS", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
