// Copyright (c) Core DF. All rights reserved.
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
