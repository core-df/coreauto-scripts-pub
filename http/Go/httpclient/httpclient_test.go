package httpclient

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type roundTripHandler http.HandlerFunc

func (f roundTripHandler) RoundTrip(req *http.Request) (*http.Response, error) {
	rec := httptest.NewRecorder()
	http.HandlerFunc(f).ServeHTTP(rec, req)
	return rec.Result(), nil
}

func withClient(t *testing.T, h http.HandlerFunc) {
	t.Helper()
	prev := httpClient
	httpClient = &http.Client{Transport: roundTripHandler(h)}
	t.Cleanup(func() { httpClient = prev })
}

func TestGet_Success(t *testing.T) {
	withClient(t, func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]bool{"ok": true})
	})
	r := Get("https://api.example/x", nil, map[string]string{"q": "1"})
	if r.StatusCode != 200 {
		t.Fatalf("%+v", r)
	}
}

func TestPost_HTTPError(t *testing.T) {
	withClient(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"detail":"missing"}`))
	})
	r := Post("https://api.example/x", map[string]any{"a": 1}, nil, nil)
	if r.StatusCode != 404 {
		t.Fatalf("%+v", r)
	}
}

func TestDelete_TransportError(t *testing.T) {
	prev := httpClient
	httpClient = &http.Client{Transport: transportErr{errors.New("timeout")}}
	t.Cleanup(func() { httpClient = prev })
	if Delete("https://x", nil).StatusCode != 0 {
		t.Fatal()
	}
}

type transportErr struct{ err error }

func (e transportErr) RoundTrip(*http.Request) (*http.Response, error) { return nil, e.err }
