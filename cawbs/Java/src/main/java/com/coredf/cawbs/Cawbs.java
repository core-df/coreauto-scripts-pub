// Copyright (c) Core DF. All rights reserved.
//
// Core Auto Web Services library (cawbs) — Java client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

package com.coredf.cawbs;

public final class Cawbs {
    private static final WbsSession SESS = new WbsSession();

    private Cawbs() {}

    public static Result Init() {
        String env = System.getenv("ENV");
        String actionId = System.getenv("ACTIONID");
        String accessCode = System.getenv("CA_ACCESS_CODE");
        String baseUrl = System.getenv("CA_WBS_URL");
        String stepName = System.getenv("STEPNAME");
        if (isBlank(env) || isBlank(actionId) || isBlank(accessCode) || isBlank(baseUrl) || isBlank(stepName)) {
            return WbsSession.missingEnv("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME");
        }
        return SESS.authenticate(env, accessCode, baseUrl);
    }

    public static Result GetEventPayload() {
        return SESS.getEventPayload(System.getenv("ACTIONID"));
    }

    public static Result PutStepPayload(Object payload) {
        return SESS.putStepPayload(System.getenv("ACTIONID"), System.getenv("STEPNAME"), payload);
    }

    public static Result GetStepPayload(String stepname) {
        return SESS.getStepPayload(System.getenv("ACTIONID"), stepname);
    }

    public static Result GetKeystore(String keylist) {
        return SESS.getKeystore(keylist);
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
