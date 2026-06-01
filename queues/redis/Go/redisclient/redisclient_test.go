package redisclient

import "testing"

func TestInit_Missing(t *testing.T) {
	t.Setenv("REDIS_HOST", "")
	t.Setenv("REDIS_URL", "")
	if Init().StatusCode != 601 {
		t.Fatal()
	}
}

func TestInit_OK(t *testing.T) {
	t.Setenv("REDIS_HOST", "redis.local")
	if Init().StatusCode != 200 {
		t.Fatal()
	}
}
