package ingressclient

import "testing"

func TestTriggerEvent_MissingName(t *testing.T) {
	t.Setenv("CA_EVENT_NAME", "")
	t.Setenv("ENV", "dev")
	t.Setenv("CA_ACCESS_CODE", "x")
	t.Setenv("CA_WBS_URL", "http://collector")
	r := TriggerEvent(map[string]any{"a": 1}, "", "")
	if r.StatusCode != 601 {
		t.Fatalf("%+v", r)
	}
}

func TestForwardMessages_BadConsume(t *testing.T) {
	r := ForwardMessages(ConsumeResult{StatusCode: 500, Error: "fail"})
	if r.StatusCode != 500 {
		t.Fatal()
	}
}
