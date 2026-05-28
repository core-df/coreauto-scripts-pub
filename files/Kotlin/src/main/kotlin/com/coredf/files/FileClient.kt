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

package com.coredf.files
import com.jcraft.jsch.*
import java.nio.charset.Charset
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption

object FileClient {
    @JvmStatic fun LocalRead(path: String, encoding: String = "utf-8") = try {
        Result.ok(mapOf("content" to Files.readString(Path.of(path), Charset.forName(encoding))))
    } catch (e: Exception) { Result.error(500, e.message) }

    @JvmStatic fun LocalWrite(path: String, content: String, encoding: String = "utf-8") = try {
        val p = Path.of(path); p.parent?.let { Files.createDirectories(it) }
        Files.writeString(p, content, Charset.forName(encoding)); Result.ok()
    } catch (e: Exception) { Result.error(500, e.message) }

    @JvmStatic fun LocalMove(src: String, dest: String) = try {
        Files.move(Path.of(src), Path.of(dest), StandardCopyOption.REPLACE_EXISTING); Result.ok()
    } catch (e: Exception) { Result.error(500, e.message) }

    private fun sftp(): ChannelSftp {
        val host = env("SFTP_HOST"); val user = env("SFTP_USER")
        require(host.isNotEmpty() && user.isNotEmpty()) { "SFTP_HOST and SFTP_USER required" }
        val jsch = JSch(); val key = env("SFTP_PRIVATE_KEY")
        if (key.isNotEmpty()) jsch.addIdentity(key)
        val session = jsch.getSession(user, host, env("SFTP_PORT", "22").toInt())
        if (key.isEmpty()) session.setPassword(env("SFTP_PASSWORD"))
        session.setConfig("StrictHostKeyChecking", "no"); session.connect(60_000)
        val ch = session.openChannel("sftp") as ChannelSftp; ch.connect(60_000); ch
    }

    @JvmStatic fun SftpGet(remotePath: String, localPath: String) = try {
        val s = sftp(); try {
            Path.of(localPath).parent?.let { Files.createDirectories(it) }; s.get(remotePath, localPath)
        } finally { s.disconnect(); s.session.disconnect() }; Result.ok()
    } catch (e: Exception) { Result.transportError(e.message) }

    @JvmStatic fun SftpPut(localPath: String, remotePath: String) = try {
        val s = sftp(); try { s.put(localPath, remotePath) } finally { s.disconnect(); s.session.disconnect() }; Result.ok()
    } catch (e: Exception) { Result.transportError(e.message) }

    @JvmStatic fun SftpList(remoteDir: String = ".") = try {
        val s = sftp(); try {
            @Suppress("UNCHECKED_CAST")
            val entries = s.ls(remoteDir) as Vector<ChannelSftp.LsEntry>
            Result.ok(mapOf("files" to entries.filter { !it.attrs.isDir }.map { it.filename }))
        } finally { s.disconnect(); s.session.disconnect() }
    } catch (e: Exception) { Result.transportError(e.message) }

    private fun env(k: String) = System.getenv(k) ?: ""
    private fun env(k: String, d: String) = env(k).ifEmpty { d }
}
