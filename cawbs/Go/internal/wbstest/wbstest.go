// Package wbstest provides helpers for cawbs Go unit tests (httptest collectors).
package wbstest

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbs"
)

// StartServer runs handler on a local test HTTP server.
func StartServer(handler http.HandlerFunc) *httptest.Server {
	return httptest.NewServer(handler)
}

// WriteJSON writes a JSON response body.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	if status != 0 {
		w.WriteHeader(status)
	}
	_ = json.NewEncoder(w).Encode(v)
}

// AssertStatusError compares status_code and error (Python dict parity).
func AssertStatusError(t *testing.T, got wbs.Result, wantCode int, wantErr any) {
	t.Helper()
	if got.StatusCode != wantCode {
		t.Fatalf("status_code = %d, want %d; full result %+v", got.StatusCode, wantCode, got)
	}
	if got.Error != wantErr {
		t.Fatalf("error = %#v, want %#v", got.Error, wantErr)
	}
}
