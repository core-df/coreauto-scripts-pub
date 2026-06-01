package rabbitclient

import "testing"

func TestInit_Missing(t *testing.T) {
	t.Setenv("RABBITMQ_HOST", "")
	t.Setenv("RABBITMQ_URL", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("RABBITMQ_HOST", "rabbit.local")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
