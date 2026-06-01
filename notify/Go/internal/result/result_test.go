package result

import "testing"

func TestMissingEnv_Returns601(t *testing.T) {
	r := MissingEnv("SLACK_WEBHOOK_URL")
	want := "Environment variables SLACK_WEBHOOK_URL should be defined"
	if r.StatusCode != 601 || r.Error != want {
		t.Fatalf("MissingEnv() = %+v", r)
	}
}

func TestTransportError_DefaultMessage(t *testing.T) {
	r := TransportError("")
	if r.StatusCode != 0 || r.Error != "inaccessible" {
		t.Fatalf("TransportError() = %+v", r)
	}
}

func TestTransportError_CustomMessage(t *testing.T) {
	r := TransportError("connection reset")
	if r.StatusCode != 0 || r.Error != "connection reset" {
		t.Fatalf("TransportError() = %+v", r)
	}
}
