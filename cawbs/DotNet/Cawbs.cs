// Copyright Core DF

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
// Core Auto Web Services library (cawbs) — .NET client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

namespace CoreAuto.Cawbs;

public static class Cawbs
{
    private static readonly WbsSession Sess = new();

    public static Task<Result> InitAsync()
    {
        var env = Environment.GetEnvironmentVariable("ENV");
        var actionId = Environment.GetEnvironmentVariable("ACTIONID");
        var accessCode = Environment.GetEnvironmentVariable("CA_ACCESS_CODE");
        var baseUrl = Environment.GetEnvironmentVariable("CA_WBS_URL");
        var stepName = Environment.GetEnvironmentVariable("STEPNAME");
        if (string.IsNullOrWhiteSpace(env) ||
            string.IsNullOrWhiteSpace(actionId) ||
            string.IsNullOrWhiteSpace(accessCode) ||
            string.IsNullOrWhiteSpace(baseUrl) ||
            string.IsNullOrWhiteSpace(stepName))
        {
            return Task.FromResult(WbsSession.MissingEnv("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME"));
        }
        return Sess.AuthenticateAsync(env, accessCode, baseUrl);
    }

    public static Task<Result> GetEventPayloadAsync() =>
        Sess.GetEventPayloadAsync(Environment.GetEnvironmentVariable("ACTIONID") ?? "");

    public static Task<Result> PutStepPayloadAsync(object payload) =>
        Sess.PutStepPayloadAsync(
            Environment.GetEnvironmentVariable("ACTIONID") ?? "",
            Environment.GetEnvironmentVariable("STEPNAME") ?? "",
            payload);

    public static Task<Result> GetStepPayloadAsync(string stepname) =>
        Sess.GetStepPayloadAsync(Environment.GetEnvironmentVariable("ACTIONID") ?? "", stepname);

    public static Task<Result> GetKeystoreAsync(string keylist) => Sess.GetKeystoreAsync(keylist);
}
