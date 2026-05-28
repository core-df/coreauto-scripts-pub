// Copyright Core DF
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Local file and SFTP helpers for Core Auto step scripts.

package fileclient

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/core-df/coreauto-scripts-pub/files/Go/internal/result"
	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

// LocalRead reads a text file from the local filesystem.
func LocalRead(path string, encoding string) result.Result {
	if encoding == "" {
		encoding = "utf-8"
	}
	if encoding != "utf-8" && encoding != "UTF-8" {
		return result.Result{StatusCode: 500, Error: fmt.Sprintf("unsupported encoding: %s", encoding)}
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return result.Result{StatusCode: 500, Error: err.Error()}
	}
	return result.Result{StatusCode: 200, Content: string(data)}
}

// LocalWrite writes text content to a local file.
func LocalWrite(path string, content string, encoding string) result.Result {
	if encoding == "" {
		encoding = "utf-8"
	}
	if encoding != "utf-8" && encoding != "UTF-8" {
		return result.Result{StatusCode: 500, Error: fmt.Sprintf("unsupported encoding: %s", encoding)}
	}
	if dir := filepath.Dir(path); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return result.Result{StatusCode: 500, Error: err.Error()}
		}
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return result.Result{StatusCode: 500, Error: err.Error()}
	}
	return result.Result{StatusCode: 200}
}

// LocalMove moves or renames a local file.
func LocalMove(src, dest string) result.Result {
	if err := os.Rename(src, dest); err != nil {
		return result.Result{StatusCode: 500, Error: err.Error()}
	}
	return result.Result{StatusCode: 200}
}

func sftpConnect() (*ssh.Client, *sftp.Client, error) {
	host := os.Getenv("SFTP_HOST")
	user := os.Getenv("SFTP_USER")
	password := os.Getenv("SFTP_PASSWORD")
	portStr := os.Getenv("SFTP_PORT")
	keyPath := os.Getenv("SFTP_PRIVATE_KEY")

	if host == "" || user == "" {
		return nil, nil, fmt.Errorf("SFTP_HOST and SFTP_USER required")
	}
	port := 22
	if portStr != "" {
		p, err := strconv.Atoi(portStr)
		if err != nil {
			return nil, nil, err
		}
		port = p
	}

	var auth []ssh.AuthMethod
	if keyPath != "" {
		keyData, err := os.ReadFile(keyPath)
		if err != nil {
			return nil, nil, err
		}
		signer, err := ssh.ParsePrivateKey(keyData)
		if err != nil {
			return nil, nil, err
		}
		auth = append(auth, ssh.PublicKeys(signer))
	} else {
		if password == "" {
			return nil, nil, fmt.Errorf("SFTP_PASSWORD or SFTP_PRIVATE_KEY required")
		}
		auth = append(auth, ssh.Password(password))
	}

	cfg := &ssh.ClientConfig{
		User:            user,
		Auth:            auth,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         60 * time.Second,
	}

	addr := fmt.Sprintf("%s:%d", host, port)
	client, err := ssh.Dial("tcp", addr, cfg)
	if err != nil {
		return nil, nil, err
	}
	sftpClient, err := sftp.NewClient(client)
	if err != nil {
		client.Close()
		return nil, nil, err
	}
	return client, sftpClient, nil
}

// SftpGet downloads a remote file to a local path.
func SftpGet(remotePath, localPath string) result.Result {
	sshClient, sftpClient, err := sftpConnect()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer sftpClient.Close()
	defer sshClient.Close()

	if dir := filepath.Dir(localPath); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return result.TransportError(err.Error())
		}
	}
	src, err := sftpClient.Open(remotePath)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer src.Close()

	dst, err := os.Create(localPath)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer dst.Close()

	if _, err := src.WriteTo(dst); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// SftpPut uploads a local file to a remote path.
func SftpPut(localPath, remotePath string) result.Result {
	sshClient, sftpClient, err := sftpConnect()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer sftpClient.Close()
	defer sshClient.Close()

	src, err := os.Open(localPath)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer src.Close()

	dst, err := sftpClient.Create(remotePath)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer dst.Close()

	if _, err := src.WriteTo(dst); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// SftpList lists files in a remote directory.
func SftpList(remoteDir string) result.Result {
	if remoteDir == "" {
		remoteDir = "."
	}
	sshClient, sftpClient, err := sftpConnect()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer sftpClient.Close()
	defer sshClient.Close()

	names, err := sftpClient.ReadDir(remoteDir)
	if err != nil {
		return result.TransportError(err.Error())
	}
	files := make([]string, len(names))
	for i, fi := range names {
		files[i] = fi.Name()
	}
	return result.Result{StatusCode: 200, Files: files}
}
