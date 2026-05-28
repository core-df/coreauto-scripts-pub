// Copyright (c) Core DF. All rights reserved.
//
// Core Auto Web Services library (cawbs) — Node.js client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

import { missingEnv, Session } from './lib/wbs.js';

const sess = new Session();
const env = process.env.ENV;
const actionID = process.env.ACTIONID;
const accessCode = process.env.CA_ACCESS_CODE;
const baseURL = process.env.CA_WBS_URL;
const stepName = process.env.STEPNAME;

export async function Init() {
  if (!env || !actionID || !accessCode || !baseURL || !stepName) {
    return missingEnv('ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME');
  }
  return sess.authenticate(env, accessCode, baseURL);
}

export async function GetEventPayload() {
  return sess.getEventPayload(actionID);
}

export async function PutStepPayload(payload) {
  return sess.putStepPayload(actionID, stepName, payload);
}

export async function GetStepPayload(stepname) {
  return sess.getStepPayload(actionID, stepname);
}

export async function GetKeystore(keylist) {
  return sess.getKeystore(keylist);
}
