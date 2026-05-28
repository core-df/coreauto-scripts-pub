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

// Local file and SFTP helpers for Core Auto step scripts.
package com.coredf.files;
import com.jcraft.jsch.*;
import java.nio.charset.Charset; import java.nio.file.*; import java.util.*;

public final class FileClient {
    private FileClient() {}
    public static Result LocalRead(String path, String encoding) {
        try { return Result.ok(Map.of("content", Files.readString(Path.of(path), Charset.forName(encoding)))); }
        catch (Exception e) { return Result.error(500, e.getMessage()); }
    }
    public static Result LocalRead(String path) { return LocalRead(path, "utf-8"); }
    public static Result LocalWrite(String path, String content, String encoding) {
        try {
            Path p = Path.of(path); if (p.getParent() != null) Files.createDirectories(p.getParent());
            Files.writeString(p, content, Charset.forName(encoding)); return Result.ok();
        } catch (Exception e) { return Result.error(500, e.getMessage()); }
    }
    public static Result LocalWrite(String path, String content) { return LocalWrite(path, content, "utf-8"); }
    public static Result LocalMove(String src, String dest) {
        try { Files.move(Path.of(src), Path.of(dest), StandardCopyOption.REPLACE_EXISTING); return Result.ok(); }
        catch (Exception e) { return Result.error(500, e.getMessage()); }
    }
    private static ChannelSftp sftpConnect() throws JSchException {
        String host = env("SFTP_HOST"), user = env("SFTP_USER");
        if (host.isEmpty() || user.isEmpty()) throw new JSchException("SFTP_HOST and SFTP_USER required");
        int port = Integer.parseInt(envOr("SFTP_PORT", "22"));
        JSch jsch = new JSch(); Session session = jsch.getSession(user, host, port);
        String key = env("SFTP_PRIVATE_KEY");
        if (!key.isEmpty()) jsch.addIdentity(key);
        else session.setPassword(env("SFTP_PASSWORD"));
        session.setConfig("StrictHostKeyChecking", "no"); session.connect(60000);
        ChannelSftp sftp = (ChannelSftp) session.openChannel("sftp"); sftp.connect(60000);
        sftp.put("session", session); return sftp;
    }
    private static void sftpClose(ChannelSftp sftp) {
        try { Session s = (Session) sftp.get("session"); sftp.disconnect(); if (s != null) s.disconnect(); } catch (Exception ignored) {}
    }
    public static Result SftpGet(String remotePath, String localPath) {
        try {
            ChannelSftp sftp = sftpConnect();
            try { Path lp = Path.of(localPath); if (lp.getParent() != null) Files.createDirectories(lp.getParent()); sftp.get(remotePath, localPath); }
            finally { sftpClose(sftp); } return Result.ok();
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result SftpPut(String localPath, String remotePath) {
        try { ChannelSftp sftp = sftpConnect(); try { sftp.put(localPath, remotePath); } finally { sftpClose(sftp); } return Result.ok(); }
        catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result SftpList(String remoteDir) {
        try {
            ChannelSftp sftp = sftpConnect();
            try { @SuppressWarnings("unchecked") Vector<ChannelSftp.LsEntry> list = sftp.ls(remoteDir == null ? "." : remoteDir);
                List<String> names = new ArrayList<>(); for (ChannelSftp.LsEntry e : list) if (!e.getAttrs().isDir()) names.add(e.getFilename());
                return Result.ok(Map.of("files", names)); } finally { sftpClose(sftp); }
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result SftpList() { return SftpList("."); }
    private static String env(String k) { String v = System.getenv(k); return v == null ? "" : v; }
    private static String envOr(String k, String d) { String v = System.getenv(k); return v == null || v.isEmpty() ? d : v; }
}
