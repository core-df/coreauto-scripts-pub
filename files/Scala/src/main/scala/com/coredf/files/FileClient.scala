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
import java.nio.file.{Files, Path, StandardCopyOption}

object FileClient:
  def LocalRead(path: String, encoding: String = "utf-8"): Result =
    try Result.ok(Map("content" -> Files.readString(Path.of(path), Charset.forName(encoding))))
    catch case e: Exception => Result.error(500, e.getMessage)

  def LocalWrite(path: String, content: String, encoding: String = "utf-8"): Result =
    try
      val p = Path.of(path); Option(p.getParent).foreach(Files.createDirectories(_))
      Files.writeString(p, content, Charset.forName(encoding)); Result.ok()
    catch case e: Exception => Result.error(500, e.getMessage)

  def LocalMove(src: String, dest: String): Result =
    try Files.move(Path.of(src), Path.of(dest), StandardCopyOption.REPLACE_EXISTING); Result.ok()
    catch case e: Exception => Result.error(500, e.getMessage)

  private def sftp(): ChannelSftp =
    val host = env("SFTP_HOST"); val user = env("SFTP_USER")
    require(host.nonEmpty && user.nonEmpty, "SFTP_HOST and SFTP_USER required")
    val jsch = new JSch(); val key = env("SFTP_PRIVATE_KEY")
    if key.nonEmpty then jsch.addIdentity(key)
    val session = jsch.getSession(user, host, env("SFTP_PORT", "22").toInt)
    if key.isEmpty then session.setPassword(env("SFTP_PASSWORD"))
    session.setConfig("StrictHostKeyChecking", "no"); session.connect(60000)
    val ch = session.openChannel("sftp").asInstanceOf[ChannelSftp]; ch.connect(60000); ch

  def SftpGet(remotePath: String, localPath: String): Result =
    try val s = sftp(); try
      Option(Path.of(localPath).getParent).foreach(Files.createDirectories(_)); s.get(remotePath, localPath)
    finally s.disconnect(); s.getSession.disconnect(); Result.ok()
    catch case e: Exception => Result.transportError(e.getMessage)

  def SftpPut(localPath: String, remotePath: String): Result =
    try val s = sftp(); try s.put(localPath, remotePath) finally s.disconnect(); s.getSession.disconnect(); Result.ok()
    catch case e: Exception => Result.transportError(e.getMessage)

  def SftpList(remoteDir: String = "."): Result =
    try val s = sftp(); try
      val entries = s.ls(remoteDir).asInstanceOf[java.util.Vector[ChannelSftp#LsEntry]]
      Result.ok(Map("files" -> entries.toArray.map(_.asInstanceOf[ChannelSftp.LsEntry]).filter(!_.getAttrs.isDir).map(_.getFilename).toList))
    finally s.disconnect(); s.getSession.disconnect()
    catch case e: Exception => Result.transportError(e.getMessage)

  private def env(k: String): String = Option(System.getenv(k)).getOrElse("")
  private def env(k: String, d: String): String = val v = env(k); if v.isEmpty then d else v
