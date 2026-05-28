// Copyright (c) Core DF. All rights reserved.
//
// Batch-oriented cawbs client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

package com.coredf.cawbs;

public final class CawbsBatch {
    private static final WbsSession SESS = new WbsSession();

    private CawbsBatch() {}

    public static Result Init() {
        String env = System.getenv("ENV");
        String accessCode = System.getenv("CA_ACCESS_CODE");
        String baseUrl = System.getenv("CA_WBS_URL");
        if (isBlank(env) || isBlank(accessCode) || isBlank(baseUrl)) {
            return WbsSession.missingEnv("ENV, CA_ACCESS_CODE, CA_WBS_URL");
        }
        return SESS.authenticate(env, accessCode, baseUrl);
    }

    public static Result GetKeystore(String keylist) {
        return SESS.getKeystore(keylist);
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
