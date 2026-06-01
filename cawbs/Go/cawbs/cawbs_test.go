package cawbs

import (
	"encoding/json"
	"io"
	"net/http"
	"testing"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbs"
	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbstest"
)

const (
	rtEnv          = "dev"
	rtActionID     = "99"
	rtAccessCode   = "secret"
	rtStepName     = "EnrichOrder"
	rtCollectorURL = "http://collector.example"
)

func resetRT(t *testing.T) {
	t.Helper()
	sess = wbs.Session{}
	t.Setenv("ENV", rtEnv)
	t.Setenv("ACTIONID", rtActionID)
	t.Setenv("CA_ACCESS_CODE", rtAccessCode)
	t.Setenv("CA_WBS_URL", rtCollectorURL)
	t.Setenv("STEPNAME", rtStepName)
}

func TestInit_MissingEnvReturns601(t *testing.T) {
	resetRT(t)
	t.Setenv("STEPNAME", "")

	r := Init()

	wbstest.AssertStatusError(t, r, 601,
		"Environment variables ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME should be defined")
}

func TestInit_SuccessSetsBearerAndStripsURL(t *testing.T) {
	resetRT(t)
	t.Setenv("CA_WBS_URL", rtCollectorURL+"///")

	var authBody map[string]string
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/auth/apicode" {
			t.Errorf("path = %s, want /v1/auth/apicode", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		_ = json.NewDecoder(r.Body).Decode(&authBody)
		wbstest.WriteJSON(w, 0, map[string]string{"token": "abc"})
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL+"///")

	r := Init()

	if r.StatusCode != 200 {
		t.Fatalf("Init() = %+v", r)
	}
	if !sess.Initialized() {
		t.Fatal("session not initialized")
	}
	if authBody["apiCode"] != rtAccessCode {
		t.Fatalf("apiCode = %#v", authBody)
	}
	if sess.Authorization() != "Bearer abc" {
		t.Fatalf("Authorization = %q", sess.Authorization())
	}
}

func TestInit_DoubleInitReturns602(t *testing.T) {
	resetRT(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		wbstest.WriteJSON(w, 0, map[string]string{"token": "abc"})
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)

	if Init().StatusCode != 200 {
		t.Fatal("first Init failed")
	}
	r := Init()
	wbstest.AssertStatusError(t, r, 602, "init already called")
}

func TestInit_AuthHTTPErrorWithJSON(t *testing.T) {
	resetRT(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		wbstest.WriteJSON(w, http.StatusUnauthorized, map[string]string{"message": "invalid code"})
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)

	r := Init()

	if r.StatusCode != 401 {
		t.Fatalf("status_code = %d, want 401", r.StatusCode)
	}
	errMap, ok := r.Error.(map[string]any)
	if !ok || errMap["message"] != "invalid code" {
		t.Fatalf("error = %#v", r.Error)
	}
}

func TestInit_AuthNonJSONReturnsInaccessible(t *testing.T) {
	resetRT(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
		_, _ = io.WriteString(w, "not json")
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)

	r := Init()

	wbstest.AssertStatusError(t, r, 502, "inaccessible")
}

func TestGetEventPayload_RequiresInit(t *testing.T) {
	resetRT(t)
	sess = wbs.Session{}

	r := GetEventPayload()

	wbstest.AssertStatusError(t, r, 603, "Init required")
}

func TestPutStepPayload_RequiresInit(t *testing.T) {
	resetRT(t)
	sess = wbs.Session{}

	r := PutStepPayload(map[string]any{})

	wbstest.AssertStatusError(t, r, 603, "Init required")
}

func TestGetEventPayload_Success(t *testing.T) {
	resetRT(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/v1/auth/apicode":
			wbstest.WriteJSON(w, 0, map[string]string{"token": "t"})
		case "/v1/rtevent/99":
			wbstest.WriteJSON(w, 0, map[string]any{"payload": map[string]string{"orderId": "1"}})
		default:
			t.Errorf("path = %s", r.URL.Path)
		}
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)
	if Init().StatusCode != 200 {
		t.Fatal("Init failed")
	}

	r := GetEventPayload()

	if r.StatusCode != 200 {
		t.Fatalf("GetEventPayload() = %+v", r)
	}
	payload, ok := r.Payload.(map[string]any)
	if !ok || payload["orderId"] != "1" {
		t.Fatalf("payload = %#v", r.Payload)
	}
}

func TestPutStepPayload_Success(t *testing.T) {
	resetRT(t)
	var posted []byte
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/v1/auth/apicode":
			wbstest.WriteJSON(w, 0, map[string]string{"token": "t"})
		case "/v1/rtstep/payload":
			posted, _ = io.ReadAll(r.Body)
		default:
			t.Errorf("path = %s", r.URL.Path)
		}
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)
	if Init().StatusCode != 200 {
		t.Fatal("Init failed")
	}

	r := PutStepPayload(map[string]any{"done": true})

	if r.StatusCode != 200 {
		t.Fatalf("PutStepPayload() = %+v", r)
	}
	var body map[string]any
	if err := json.Unmarshal(posted, &body); err != nil {
		t.Fatal(err)
	}
	if body["actionId"] != rtActionID || body["stepname"] != rtStepName {
		t.Fatalf("body = %#v", body)
	}
	if payload, ok := body["payload"].(map[string]any); !ok || payload["done"] != true {
		t.Fatalf("payload = %#v", body["payload"])
	}
}

func TestGetKeystore_MissingKeyReturns605(t *testing.T) {
	resetRT(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/v1/auth/apicode":
			wbstest.WriteJSON(w, 0, map[string]string{"token": "t"})
		case "/v1/keystore/db_user,db_password":
			wbstest.WriteJSON(w, 0, map[string]string{"db_user": "u1"})
		default:
			t.Errorf("path = %s", r.URL.Path)
		}
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)
	if Init().StatusCode != 200 {
		t.Fatal("Init failed")
	}

	r := GetKeystore("db_user, db_password")

	wbstest.AssertStatusError(t, r, 605, "db_password not found")
}

func TestGetKeystore_SuccessStripsSpaces(t *testing.T) {
	resetRT(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/v1/auth/apicode":
			wbstest.WriteJSON(w, 0, map[string]string{"token": "t"})
		case "/v1/keystore/a,b":
			wbstest.WriteJSON(w, 0, map[string]string{"a": "1", "b": "2"})
		default:
			t.Errorf("path = %s", r.URL.Path)
		}
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)
	if Init().StatusCode != 200 {
		t.Fatal("Init failed")
	}

	r := GetKeystore("a, b")

	if r.StatusCode != 200 || r.Answer["a"] != "1" || r.Answer["b"] != "2" {
		t.Fatalf("GetKeystore() = %+v", r)
	}
}
