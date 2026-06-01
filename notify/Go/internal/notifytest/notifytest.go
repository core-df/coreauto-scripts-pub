// Package notifytest provides helpers for notify Go unit tests.
package notifytest

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/core-df/coreauto-scripts-pub/notify/Go/internal/result"
)

// AssertStatusError compares status_code and error (Python dict parity).
func AssertStatusError(t *testing.T, got result.Result, wantCode int, wantErr any) {
	t.Helper()
	if got.StatusCode != wantCode {
		t.Fatalf("status_code = %d, want %d; full result %+v", got.StatusCode, wantCode, got)
	}
	if got.Error != wantErr {
		t.Fatalf("error = %#v, want %#v", got.Error, wantErr)
	}
}

// RoundTripHandler runs an HTTP handler during client RoundTrip (no network).
type RoundTripHandler http.HandlerFunc

func (f RoundTripHandler) RoundTrip(req *http.Request) (*http.Response, error) {
	rec := httptest.NewRecorder()
	http.HandlerFunc(f).ServeHTTP(rec, req)
	return rec.Result(), nil
}

// HTTPClient returns an *http.Client whose transport runs handler (no network).
func HTTPClient(handler http.HandlerFunc) *http.Client {
	return &http.Client{Transport: RoundTripHandler(handler)}
}

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

// ReadJSONBody decodes the request JSON body.
func ReadJSONBody(t *testing.T, req *http.Request, dest any) {
	t.Helper()
	if err := json.NewDecoder(req.Body).Decode(dest); err != nil {
		t.Fatalf("decode body: %v", err)
	}
}

// ReadRawBody reads the full request body.
func ReadRawBody(t *testing.T, req *http.Request) []byte {
	t.Helper()
	b, err := io.ReadAll(req.Body)
	if err != nil {
		t.Fatalf("read body: %v", err)
	}
	return b
}
