package pubsubclient

import "testing"

func TestInit_Missing(t *testing.T) {
	t.Setenv("PUBSUB_PROJECT_ID", "")
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("PUBSUB_PROJECT_ID", "proj")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
