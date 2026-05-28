// Copyright (c) Core DF. All rights reserved.
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
