package s3client

import "testing"

func TestInit_MissingCredentials(t *testing.T) {
	t.Setenv("AWS_ACCESS_KEY_ID", "")
	t.Setenv("AWS_PROFILE", "")
	if Init().StatusCode != 601 {
		t.Fatalf("%+v", Init())
	}
}

func TestInit_Success(t *testing.T) {
	t.Setenv("AWS_ACCESS_KEY_ID", "k")
	t.Setenv("S3_BUCKET", "b")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}

func TestGetObject_MissingBucket(t *testing.T) {
	t.Setenv("S3_BUCKET", "")
	if GetObject("key", "").StatusCode != 601 {
		t.Fatal()
	}
}

func TestPutObject_ExplicitBucket(t *testing.T) {
	t.Setenv("AWS_ACCESS_KEY_ID", "k")
	// Without live AWS, PutObject should fail transport — not 601 when bucket provided.
	r := PutObject("k", "data", "explicit-bucket")
	if r.StatusCode == 601 {
		t.Fatalf("unexpected missing env: %+v", r)
	}
}
