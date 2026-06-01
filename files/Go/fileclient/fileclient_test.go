package fileclient

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

func TestLocalReadWriteMove(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "a", "f.txt")
	if LocalWrite(p, "hello", "").StatusCode != 200 {
		t.Fatal()
	}
	if LocalRead(p, "").Content != "hello" {
		t.Fatal()
	}
	dest := filepath.Join(dir, "b", "f.txt")
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		t.Fatal(err)
	}
	if LocalMove(p, dest).StatusCode != 200 {
		t.Fatal()
	}
	if _, err := os.Stat(p); !os.IsNotExist(err) {
		t.Fatal("source should be moved")
	}
}

func TestSftpConnect_MissingEnv(t *testing.T) {
	t.Setenv("SFTP_HOST", "")
	t.Setenv("SFTP_USER", "")
	_, _, err := sftpConnectImpl()
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestSftpGet_ConnectError(t *testing.T) {
	t.Setenv("SFTP_HOST", "127.0.0.1")
	t.Setenv("SFTP_USER", "u")
	t.Setenv("SFTP_PASSWORD", "p")
	t.Setenv("SFTP_PORT", "1")
	prev := sftpConnectFn
	sftpConnectFn = func() (*ssh.Client, *sftp.Client, error) {
		return nil, nil, errors.New("connection refused")
	}
	t.Cleanup(func() { sftpConnectFn = prev })
	r := SftpGet("/r", t.TempDir()+"/out")
	if r.StatusCode != 0 {
		t.Fatalf("%+v", r)
	}
}
