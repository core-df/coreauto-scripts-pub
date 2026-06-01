package cawbsingress

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbs"
	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbstest"
)

const (
	ingressEnv        = "dev"
	ingressAccessCode = "secret"
)

func resetIngress(t *testing.T) {
	t.Helper()
	sess = wbs.Session{}
	t.Setenv("ENV", ingressEnv)
	t.Setenv("CA_ACCESS_CODE", ingressAccessCode)
	t.Setenv("CA_WBS_URL", "http://collector.example")
}

func TestInit_MissingEnvReturns601(t *testing.T) {
	resetIngress(t)
	t.Setenv("CA_ACCESS_CODE", "")

	r := Init()

	if r.StatusCode != 601 {
		t.Fatalf("status_code = %d, want 601", r.StatusCode)
	}
	msg, ok := r.Error.(string)
	if !ok || !strings.Contains(msg, "ENV, CA_ACCESS_CODE, CA_WBS_URL") {
		t.Fatalf("error = %#v", r.Error)
	}
}

func TestPostEvent_RequiresInit(t *testing.T) {
	resetIngress(t)
	sess = wbs.Session{}

	r := PostEvent("Evt", map[string]any{})

	wbstest.AssertStatusError(t, r, 603, "Init required")
}

func TestPostEvent_Success(t *testing.T) {
	resetIngress(t)
	var posted []byte
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/v1/auth/apicode":
			wbstest.WriteJSON(w, 0, map[string]string{"token": "t"})
		case "/v1/rtevent":
			posted, _ = io.ReadAll(r.Body)
			wbstest.WriteJSON(w, http.StatusCreated, map[string]any{
				"eventId":   1,
				"actionId":  42,
				"createdAt": "2026-01-01T00:00:00Z",
			})
		default:
			t.Errorf("path = %s", r.URL.Path)
		}
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)
	if Init().StatusCode != 200 {
		t.Fatal("Init failed")
	}

	r := PostEvent("OrderCreated", map[string]string{"orderId": "123"}, "kafka")

	if r.StatusCode != 201 {
		t.Fatalf("PostEvent() = %+v", r)
	}
	if r.EventID != float64(1) || r.ActionID != float64(42) || r.CreatedAt != "2026-01-01T00:00:00Z" {
		t.Fatalf("PostEvent() = %+v", r)
	}
	var body map[string]any
	if err := json.Unmarshal(posted, &body); err != nil {
		t.Fatal(err)
	}
	if body["eventName"] != "OrderCreated" || body["eventSource"] != "kafka" {
		t.Fatalf("body = %#v", body)
	}
}

func TestSubmitFlag_Success(t *testing.T) {
	resetIngress(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/v1/auth/apicode":
			wbstest.WriteJSON(w, 0, map[string]string{"token": "t"})
		case "/v1/flag":
			wbstest.WriteJSON(w, 0, map[string]string{"status": "accepted"})
		default:
			t.Errorf("path = %s", r.URL.Path)
		}
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)
	if Init().StatusCode != 200 {
		t.Fatal("Init failed")
	}

	r := SubmitFlag("daily", "ERP", "SAP", "2026-06-01")

	if r.StatusCode != 200 || r.FlagStatus != "accepted" {
		t.Fatalf("SubmitFlag() = %+v", r)
	}
}
