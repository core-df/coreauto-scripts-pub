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
// Batch-oriented cawbs client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

namespace CoreAuto.Cawbs;

public static class CawbsBatch
{
    private static readonly WbsSession Sess = new();

    public static Task<Result> InitAsync()
    {
        var env = Environment.GetEnvironmentVariable("ENV");
        var accessCode = Environment.GetEnvironmentVariable("CA_ACCESS_CODE");
        var baseUrl = Environment.GetEnvironmentVariable("CA_WBS_URL");
        if (string.IsNullOrWhiteSpace(env) ||
            string.IsNullOrWhiteSpace(accessCode) ||
            string.IsNullOrWhiteSpace(baseUrl))
        {
            return Task.FromResult(WbsSession.MissingEnv("ENV, CA_ACCESS_CODE, CA_WBS_URL"));
        }
        return Sess.AuthenticateAsync(env, accessCode, baseUrl);
    }

    public static Task<Result> GetKeystoreAsync(string keylist) => Sess.GetKeystoreAsync(keylist);
}
