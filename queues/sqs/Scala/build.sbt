name := "coreauto"
version := "1.0.0"
scalaVersion := "3.3.4"
licenses += ("Apache-2.0" -> url("http://www.apache.org/licenses/LICENSE-2.0"))
libraryDependencies ++= Seq(
  "software.amazon.awssdk" % "sqs" % "2.25.27"
)
