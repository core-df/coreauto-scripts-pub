package notifyclient

import (
	"errors"
	"fmt"
	"net/http"
	"net/smtp"
	"strings"
	"testing"

	"github.com/core-df/coreauto-scripts-pub/notify/Go/internal/notifytest"
	"github.com/core-df/coreauto-scripts-pub/notify/Go/internal/smtptest"
)

func withHTTPClient(t *testing.T, c *http.Client) {
	t.Helper()
	prev := notifyHTTP
	notifyHTTP = c
	t.Cleanup(func() { notifyHTTP = prev })
}

func withSMTPDial(t *testing.T, fn func(addr string) (*smtp.Client, error)) {
	t.Helper()
	prev := smtpDial
	smtpDial = fn
	t.Cleanup(func() { smtpDial = prev })
}

func TestSlack_MissingWebhookReturns601(t *testing.T) {
	r := Slack("hello", "")

	notifytest.AssertStatusError(t, r, 601,
		"Environment variables SLACK_WEBHOOK_URL should be defined")
}

func TestSlack_SuccessWithExplicitURL(t *testing.T) {
	var gotBody map[string]string
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.String() != "https://hooks.slack.com/x" {
			t.Errorf("url = %s", r.URL.String())
		}
		notifytest.ReadJSONBody(t, r, &gotBody)
		notifytest.WriteJSON(w, 200, map[string]string{})
	}))

	r := Slack("hello", "https://hooks.slack.com/x")

	if r.StatusCode != 200 {
		t.Fatalf("Slack() = %+v", r)
	}
	if gotBody["text"] != "hello" {
		t.Fatalf("body = %#v", gotBody)
	}
}

func TestSlack_SuccessFromEnv(t *testing.T) {
	t.Setenv("SLACK_WEBHOOK_URL", "https://hooks.slack.com/env")
	var url string
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		url = r.URL.String()
		notifytest.WriteJSON(w, 200, map[string]string{})
	}))

	r := Slack("ping", "")

	if r.StatusCode != 200 || url != "https://hooks.slack.com/env" {
		t.Fatalf("Slack() = %+v, url = %s", r, url)
	}
}

func TestSlack_HTTPError(t *testing.T) {
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("invalid_payload"))
	}))

	r := Slack("x", "https://hooks.slack.com/x")

	if r.StatusCode != 400 || r.Error != "invalid_payload" {
		t.Fatalf("Slack() = %+v", r)
	}
}

func TestSlack_TransportError(t *testing.T) {
	withHTTPClient(t, &http.Client{Transport: roundTripError{errors.New("refused")}})

	r := Slack("x", "https://hooks.slack.com/x")

	if r.StatusCode != 0 || !strings.Contains(r.Error.(string), "refused") {
		t.Fatalf("Slack() = %+v", r)
	}
}

type roundTripError struct{ err error }

func (e roundTripError) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, e.err
}

func TestTeams_MissingWebhookReturns601(t *testing.T) {
	r := Teams("alert", "")

	notifytest.AssertStatusError(t, r, 601,
		"Environment variables TEAMS_WEBHOOK_URL should be defined")
}

func TestTeams_SuccessMessageCardPayload(t *testing.T) {
	var payload map[string]string
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		notifytest.ReadJSONBody(t, r, &payload)
		notifytest.WriteJSON(w, 200, map[string]string{})
	}))

	r := Teams("alert", "https://teams.example/webhook")

	if r.StatusCode != 200 {
		t.Fatalf("Teams() = %+v", r)
	}
	if payload["@type"] != "MessageCard" || payload["@context"] != "http://schema.org/extensions" || payload["text"] != "alert" {
		t.Fatalf("payload = %#v", payload)
	}
}

func TestTeams_HTTPError(t *testing.T) {
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte("forbidden"))
	}))

	r := Teams("x", "https://teams.example/h")

	if r.StatusCode != 403 || r.Error != "forbidden" {
		t.Fatalf("Teams() = %+v", r)
	}
}

func TestEmail_MissingSMTPConfigReturns601(t *testing.T) {
	r := Email("Subj", "body", "ops@example.com", "")

	notifytest.AssertStatusError(t, r, 601,
		"Environment variables SMTP_HOST and SMTP_FROM (or from_addr) should be defined")
}

func TestEmail_SuccessWithoutAuth(t *testing.T) {
	srv, err := smtptest.Start(false)
	if err != nil {
		t.Fatal(err)
	}
	defer srv.Close()

	t.Setenv("SMTP_HOST", srv.Host)
	t.Setenv("SMTP_PORT", fmt.Sprint(srv.Port))
	t.Setenv("SMTP_FROM", "alerts@example.com")
	t.Setenv("SMTP_USER", "")
	t.Setenv("SMTP_PASSWORD", "")

	r := Email("Subj", "body text", "a@x.com, b@y.com", "")

	if r.StatusCode != 200 {
		t.Fatalf("Email() = %+v", r)
	}
	mail := srv.LastMail()
	if mail.From != "alerts@example.com" {
		t.Fatalf("from = %q", mail.From)
	}
	if len(mail.To) != 2 || mail.To[0] != "a@x.com" || mail.To[1] != "b@y.com" {
		t.Fatalf("to = %#v", mail.To)
	}
}

func TestEmail_SuccessWithAuth(t *testing.T) {
	srv, err := smtptest.Start(true)
	if err != nil {
		t.Fatal(err)
	}
	defer srv.Close()

	t.Setenv("SMTP_HOST", srv.Host)
	t.Setenv("SMTP_PORT", fmt.Sprint(srv.Port))
	t.Setenv("SMTP_USER", "user")
	t.Setenv("SMTP_PASSWORD", "pass")
	t.Setenv("SMTP_FROM", "alerts@example.com")

	r := Email("Subj", "body", "ops@example.com", "")

	if r.StatusCode != 200 {
		t.Fatalf("Email() = %+v", r)
	}
}

func TestEmail_FromAddrOverride(t *testing.T) {
	srv, err := smtptest.Start(false)
	if err != nil {
		t.Fatal(err)
	}
	defer srv.Close()

	t.Setenv("SMTP_HOST", srv.Host)
	t.Setenv("SMTP_PORT", fmt.Sprint(srv.Port))
	t.Setenv("SMTP_FROM", "ignored@example.com")

	Email("Subj", "body", "to@example.com", "custom@example.com")

	if srv.LastMail().From != "custom@example.com" {
		t.Fatalf("from = %q", srv.LastMail().From)
	}
}

func TestEmail_SMTPExceptionReturnsTransportError(t *testing.T) {
	withSMTPDial(t, func(string) (*smtp.Client, error) {
		return nil, errors.New("relay denied")
	})
	t.Setenv("SMTP_HOST", "smtp.example.com")
	t.Setenv("SMTP_FROM", "a@b.com")

	r := Email("Subj", "body", "to@example.com", "")

	if r.StatusCode != 0 || !strings.Contains(r.Error.(string), "relay denied") {
		t.Fatalf("Email() = %+v", r)
	}
}

func TestPagerDuty_MissingRoutingKeyReturns601(t *testing.T) {
	r := PagerDuty("incident", "", "")

	notifytest.AssertStatusError(t, r, 601,
		"Environment variables PAGERDUTY_ROUTING_KEY should be defined")
}

func TestPagerDuty_Success(t *testing.T) {
	var payload map[string]any
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.String() != "https://events.pagerduty.com/v2/enqueue" {
			t.Errorf("url = %s", r.URL.String())
		}
		notifytest.ReadJSONBody(t, r, &payload)
		notifytest.WriteJSON(w, http.StatusAccepted, map[string]string{
			"status":  "success",
			"message": "Event processed",
		})
	}))

	r := PagerDuty("Pipeline failed", "routing-key-abc", "warning")

	if r.StatusCode != 200 {
		t.Fatalf("PagerDuty() = %+v", r)
	}
	body, ok := r.Body.(map[string]any)
	if !ok || body["status"] != "success" {
		t.Fatalf("body = %#v", r.Body)
	}
	if payload["routing_key"] != "routing-key-abc" {
		t.Fatalf("routing_key = %#v", payload["routing_key"])
	}
	inner, ok := payload["payload"].(map[string]any)
	if !ok {
		t.Fatalf("payload.payload = %#v", payload["payload"])
	}
	if inner["summary"] != "Pipeline failed" || inner["severity"] != "warning" || inner["source"] != "coreauto-step" {
		t.Fatalf("payload.payload = %#v", inner)
	}
}

func TestPagerDuty_SuccessFromEnv(t *testing.T) {
	t.Setenv("PAGERDUTY_ROUTING_KEY", "env-key")
	var payload map[string]any
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		notifytest.ReadJSONBody(t, r, &payload)
		notifytest.WriteJSON(w, http.StatusAccepted, map[string]string{"status": "ok"})
	}))

	r := PagerDuty("alert", "", "")

	if r.StatusCode != 200 || payload["routing_key"] != "env-key" {
		t.Fatalf("PagerDuty() = %+v, payload = %#v", r, payload)
	}
}

func TestPagerDuty_HTTPError(t *testing.T) {
	withHTTPClient(t, notifytest.HTTPClient(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("bad request"))
	}))

	r := PagerDuty("x", "key", "")

	if r.StatusCode != 400 || r.Error != "bad request" {
		t.Fatalf("PagerDuty() = %+v", r)
	}
}

func TestPagerDuty_TransportError(t *testing.T) {
	withHTTPClient(t, &http.Client{Transport: roundTripError{errors.New("timed out")}})

	r := PagerDuty("x", "key", "")

	if r.StatusCode != 0 || !strings.Contains(r.Error.(string), "timed out") {
		t.Fatalf("PagerDuty() = %+v", r)
	}
}
