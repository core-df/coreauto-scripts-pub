package natsclient

import "testing"

func TestInit_Missing(t *testing.T) {
	t.Setenv("NATS_URL", "")
	t.Setenv("NATS_SERVERS", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("NATS_URL", "nats://localhost:4222")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
