// Copyright (c) Core DF. All rights reserved.
//
// Documentation: https://coreauto.coredf.com/resources

import Foundation

public enum Cawbs {
    private static let sess = WbsSession()

    public static func initSession() -> Result {
        let env = ProcessInfo.processInfo.environment["ENV"] ?? ""
        let actionID = ProcessInfo.processInfo.environment["ACTIONID"] ?? ""
        let accessCode = ProcessInfo.processInfo.environment["CA_ACCESS_CODE"] ?? ""
        let baseURL = ProcessInfo.processInfo.environment["CA_WBS_URL"] ?? ""
        let stepName = ProcessInfo.processInfo.environment["STEPNAME"] ?? ""
        if env.isEmpty || actionID.isEmpty || accessCode.isEmpty || baseURL.isEmpty || stepName.isEmpty {
            return WbsSession.missingEnv("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME")
        }
        return sess.authenticate(env: env, accessCode: accessCode, baseURL: baseURL)
    }

    public static func getEventPayload() -> Result {
        sess.getEventPayload(actionID: ProcessInfo.processInfo.environment["ACTIONID"] ?? "")
    }

    public static func putStepPayload(_ payload: Any) -> Result {
        sess.putStepPayload(
            actionID: ProcessInfo.processInfo.environment["ACTIONID"] ?? "",
            stepName: ProcessInfo.processInfo.environment["STEPNAME"] ?? "",
            payload: payload
        )
    }

    public static func getStepPayload(stepname: String) -> Result {
        sess.getStepPayload(
            actionID: ProcessInfo.processInfo.environment["ACTIONID"] ?? "",
            stepName: stepname
        )
    }

    public static func getKeystore(keylist: String) -> Result {
        sess.getKeystore(keylist: keylist)
    }
}

public enum CawbsBatch {
    private static let sess = WbsSession()

    public static func initSession() -> Result {
        let env = ProcessInfo.processInfo.environment["ENV"] ?? ""
        let accessCode = ProcessInfo.processInfo.environment["CA_ACCESS_CODE"] ?? ""
        let baseURL = ProcessInfo.processInfo.environment["CA_WBS_URL"] ?? ""
        if env.isEmpty || accessCode.isEmpty || baseURL.isEmpty {
            return WbsSession.missingEnv("ENV, CA_ACCESS_CODE, CA_WBS_URL")
        }
        return sess.authenticate(env: env, accessCode: accessCode, baseURL: baseURL)
    }

    public static func getKeystore(keylist: String) -> Result {
        sess.getKeystore(keylist: keylist)
    }
}
