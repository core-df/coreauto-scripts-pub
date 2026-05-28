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

using System.Text;
using Renci.SshNet;

namespace CoreAuto.Files;

public static class FileClient
{
    public static Result LocalRead(string path, string encoding = "utf-8")
    {
        try { return Result.Ok(new() { ["content"] = File.ReadAllText(path, Encoding.GetEncoding(encoding)) }); }
        catch (Exception ex) { return Result.Error(500, ex.Message); }
    }

    public static Result LocalWrite(string path, string content, string encoding = "utf-8")
    {
        try { Directory.CreateDirectory(Path.GetDirectoryName(path)!); File.WriteAllText(path, content, Encoding.GetEncoding(encoding)); return Result.Ok(); }
        catch (Exception ex) { return Result.Error(500, ex.Message); }
    }

    public static Result LocalMove(string src, string dest)
    {
        try { File.Move(src, dest, overwrite: true); return Result.Ok(); }
        catch (Exception ex) { return Result.Error(500, ex.Message); }
    }

    public static Result SftpGet(string remotePath, string localPath)
    {
        try { using var s = Connect(); Directory.CreateDirectory(Path.GetDirectoryName(localPath)!); using var fs = File.Create(localPath); s.DownloadFile(remotePath, fs); return Result.Ok(); }
        catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    public static Result SftpPut(string localPath, string remotePath)
    {
        try { using var s = Connect(); using var fs = File.OpenRead(localPath); s.UploadFile(fs, remotePath); return Result.Ok(); }
        catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    public static Result SftpList(string remoteDir = ".")
    {
        try { using var s = Connect(); var files = s.ListDirectory(remoteDir).Where(e => !e.IsDirectory).Select(e => e.Name).ToList(); return Result.Ok(new() { ["files"] = files }); }
        catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    private static SftpClient Connect()
    {
        var host = Env("SFTP_HOST"); var user = Env("SFTP_USER");
        if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(user)) throw new InvalidOperationException("SFTP_HOST and SFTP_USER required");
        var port = int.Parse(Env("SFTP_PORT", "22"));
        var key = Env("SFTP_PRIVATE_KEY");
        if (!string.IsNullOrEmpty(key)) return new SftpClient(host, port, user, new PrivateKeyFile(key));
        return new SftpClient(host, port, user, Env("SFTP_PASSWORD"));
    }

    private static string Env(string k, string d = "") => Environment.GetEnvironmentVariable(k) ?? d;
}
