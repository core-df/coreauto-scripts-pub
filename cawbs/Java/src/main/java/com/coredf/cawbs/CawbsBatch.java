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
