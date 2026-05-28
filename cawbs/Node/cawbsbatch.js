// Copyright (c) Core DF. All rights reserved.
//
// Batch-oriented cawbs client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

import { missingEnv, Session } from './lib/wbs.js';

const sess = new Session();
const env = process.env.ENV;
const accessCode = process.env.CA_ACCESS_CODE;
const baseURL = process.env.CA_WBS_URL;

export async function Init() {
  if (!env || !accessCode || !baseURL) {
    return missingEnv('ENV, CA_ACCESS_CODE, CA_WBS_URL');
  }
  return sess.authenticate(env, accessCode, baseURL);
}

export async function GetKeystore(keylist) {
  return sess.getKeystore(keylist);
}
