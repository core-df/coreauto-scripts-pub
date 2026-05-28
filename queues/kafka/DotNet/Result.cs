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

using System.Text.Json.Serialization;
namespace CoreAuto.Kafka;
public sealed class Result {
  [JsonPropertyName("status_code")] public int StatusCode { get; init; }
  [JsonExtensionData] public Dictionary<string, object?>? Extra { get; init; }
  public static Result Ok(Dictionary<string, object?>? extra = null) => new() { StatusCode = 200, Extra = extra };
  public static Result Error(int code, object? error) => new() { StatusCode = code, Extra = new() { ["error"] = error } };
  public static Result MissingEnv(string v) => Error(601, $"Environment variables {v} should be defined");
  public static Result TransportError(string m = "inaccessible") => Error(0, m);
}
