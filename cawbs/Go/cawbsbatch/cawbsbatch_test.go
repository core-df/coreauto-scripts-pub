package cawbsbatch

import (
	"net/http"
	"testing"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbs"
	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbstest"
)

const (
	batchEnv        = "dev"
	batchAccessCode = "secret"
)

func resetBatch(t *testing.T) {
	t.Helper()
	sess = wbs.Session{}
	t.Setenv("ENV", batchEnv)
	t.Setenv("CA_ACCESS_CODE", batchAccessCode)
	t.Setenv("CA_WBS_URL", "http://collector.example")
}

func TestInit_MissingEnvReturns601(t *testing.T) {
	resetBatch(t)
	t.Setenv("CA_WBS_URL", "")

	r := Init()

	wbstest.AssertStatusError(t, r, 601,
		"Environment variables ENV, CA_ACCESS_CODE, CA_WBS_URL should be defined")
}

func TestInit_Success(t *testing.T) {
	resetBatch(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		wbstest.WriteJSON(w, 0, map[string]string{"token": "batch-tok"})
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)

	r := Init()

	if r.StatusCode != 200 {
		t.Fatalf("Init() = %+v", r)
	}
	if sess.Authorization() != "Bearer batch-tok" {
		t.Fatalf("Authorization = %q", sess.Authorization())
	}
}

func TestInit_DoubleInitReturns602(t *testing.T) {
	resetBatch(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		wbstest.WriteJSON(w, 0, map[string]string{"token": "x"})
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)

	Init()
	r := Init()
	wbstest.AssertStatusError(t, r, 602, "init already called")
}

func TestGetKeystore_RequiresInit(t *testing.T) {
	resetBatch(t)
	sess = wbs.Session{}

	r := GetKeystore("key")

	wbstest.AssertStatusError(t, r, 603, "Init required")
}

func TestGetKeystore_Success(t *testing.T) {
	resetBatch(t)
	srv := wbstest.StartServer(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/v1/auth/apicode":
			wbstest.WriteJSON(w, 0, map[string]string{"token": "t"})
		case "/v1/keystore/secret":
			wbstest.WriteJSON(w, 0, map[string]string{"secret": "value"})
		default:
			t.Errorf("path = %s", r.URL.Path)
		}
	})
	defer srv.Close()
	t.Setenv("CA_WBS_URL", srv.URL)
	if Init().StatusCode != 200 {
		t.Fatal("Init failed")
	}

	r := GetKeystore("secret")

	if r.StatusCode != 200 || r.Answer["secret"] != "value" {
		t.Fatalf("GetKeystore() = %+v", r)
	}
}
