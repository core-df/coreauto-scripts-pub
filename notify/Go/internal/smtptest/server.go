// Package smtptest provides a minimal SMTP server for notify unit tests.
package smtptest

import (
	"bufio"
	"fmt"
	"net"
	"strings"
	"sync"
)

// Mail records one message accepted by the test server.
type Mail struct {
	From    string
	To      []string
	Message string
}

// Server is a localhost SMTP listener for unit tests.
type Server struct {
	Host  string
	Port  int
	Auth  bool
	mu    sync.Mutex
	Mails []Mail
	ln    net.Listener
}

// Start listens on 127.0.0.1:0 and serves SMTP in the background.
func Start(auth bool) (*Server, error) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return nil, err
	}
	addr := ln.Addr().(*net.TCPAddr)
	s := &Server{
		Host: "127.0.0.1",
		Port: addr.Port,
		Auth: auth,
		ln:   ln,
	}
	go s.acceptLoop()
	return s, nil
}

// Close shuts down the listener.
func (s *Server) Close() error {
	if s.ln == nil {
		return nil
	}
	return s.ln.Close()
}

// Addr returns host:port for smtp.Dial.
func (s *Server) Addr() string {
	return fmt.Sprintf("%s:%d", s.Host, s.Port)
}

func (s *Server) acceptLoop() {
	for {
		conn, err := s.ln.Accept()
		if err != nil {
			return
		}
		go s.handle(conn)
	}
}

func (s *Server) handle(conn net.Conn) {
	defer conn.Close()
	reader := bufio.NewReader(conn)
	send := func(msg string) {
		_, _ = conn.Write([]byte(msg))
	}
	read := func() string {
		line, err := reader.ReadString('\n')
		if err != nil {
			return ""
		}
		return strings.TrimSpace(line)
	}

	send("220 smtptest.example ESMTP\r\n")
	var mail Mail

	for {
		line := read()
		if line == "" {
			return
		}
		upper := strings.ToUpper(line)
		switch {
		case strings.HasPrefix(upper, "EHLO") || strings.HasPrefix(upper, "HELO"):
			send("250-smtptest.example Hello\r\n")
			if s.Auth {
				send("250-AUTH PLAIN\r\n")
			}
			send("250 OK\r\n")
		case strings.HasPrefix(upper, "AUTH"):
			send("235 Authentication successful\r\n")
		case strings.HasPrefix(upper, "MAIL FROM"):
			mail.From = strings.Trim(line[strings.Index(line, ":")+1:], " <>")
			send("250 OK\r\n")
		case strings.HasPrefix(upper, "RCPT TO"):
			rcpt := strings.Trim(line[strings.Index(line, ":")+1:], " <>")
			mail.To = append(mail.To, rcpt)
			send("250 OK\r\n")
		case strings.HasPrefix(upper, "DATA"):
			send("354 End data with <CR><LF>.<CR><LF>\r\n")
			var sb strings.Builder
			for {
				l, err := reader.ReadString('\n')
				if err != nil {
					break
				}
				if l == ".\r\n" || l == ".\n" {
					break
				}
				sb.WriteString(l)
			}
			mail.Message = sb.String()
			s.mu.Lock()
			s.Mails = append(s.Mails, mail)
			s.mu.Unlock()
			mail = Mail{}
			send("250 OK\r\n")
		case strings.HasPrefix(upper, "QUIT"):
			send("221 Bye\r\n")
			return
		default:
			send("250 OK\r\n")
		}
	}
}

// LastMail returns the most recently received message.
func (s *Server) LastMail() Mail {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.Mails) == 0 {
		return Mail{}
	}
	return s.Mails[len(s.Mails)-1]
}
