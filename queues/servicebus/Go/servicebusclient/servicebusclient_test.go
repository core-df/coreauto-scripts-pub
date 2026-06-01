package servicebusclient

import "testing"

func TestInit_Missing(t *testing.T) {
	t.Setenv("SERVICE_BUS_CONNECTION_STRING", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("SERVICE_BUS_CONNECTION_STRING", "Endpoint=sb://x")
	t.Setenv("SERVICE_BUS_QUEUE_NAME", "q")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
