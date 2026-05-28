"""
Copyright Core DF

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Core Auto Web Services library (cawbs) — Python client for the Core Auto Collector.

Provides HTTP access to the Core Auto Collector REST API for real-time step scripts.
Part of the coreauto-scripts-pub repository; not related to coreauto-mngr-pub
(PostgreSQL-backed agents and workers).

Documentation: https://coreauto.coredf.com/resources

Required environment variables:
    ENV            - Target environment name (sent as the Environment header).
    ACTIONID       - Real-time action identifier for the current run.
    CA_ACCESS_CODE - API access code used to obtain a bearer token.
    CA_WBS_URL     - Base URL of the Core Auto Collector web service.
    STEPNAME       - Name of the current step (used by PutStepPayload).

Typical usage:
    import cawbs
    result = cawbs.Init()
    if result.get("status_code") != 200:
        ...
    payload = cawbs.GetEventPayload()
    cawbs.PutStepPayload({"key": "value"})
"""

import os
import requests
import json

# Module state populated from environment and updated by Init().
wbs_iniflag = False
wbs_env = os.environ.get('ENV')
wbs_actionid = os.environ.get('ACTIONID')
wbs_accesscode = os.environ.get('CA_ACCESS_CODE')
wbs_url = os.environ.get('CA_WBS_URL')
wbs_step = os.environ.get('STEPNAME')
wbs_headers = {}


def Init():
  """Authenticate with the Collector and prepare shared request headers.

  Exchanges CA_ACCESS_CODE for a bearer token via POST /v1/auth/apicode.
  Must be called once before any other API function.

  Returns:
      dict: {'status_code': 200} on success, or an error dict with
            status_code 601 (missing env), 602 (already initialized), or
            the HTTP/API error from the Collector.
  """
  global wbs_headers, wbs_iniflag, wbs_url
  if wbs_env==None or wbs_actionid==None or wbs_accesscode==None or wbs_url==None or wbs_step==None:
    return { 'status_code':601, 'error':'Environment variables ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME should be defined' }
  elif wbs_iniflag  :
    return { 'status_code':602, 'error':'init already called' }
  wbs_url=wbs_url.strip('/ ')
  todo = { "apiCode": wbs_accesscode }
  wbs_headers =  {"Content-Type":"application/json", "Environment":wbs_env}
  response = requests.post(wbs_url + '/v1/auth/apicode', data=json.dumps(todo), headers=wbs_headers)

  if response.status_code >= 400:
    try:
      js = response.json()
    except :
      return {'status_code': response.status_code, 'error': 'inaccessible'}
    return {'status_code': response.status_code, 'error': js}

  js = response.json()
  wbs_headers["Authorization"]= 'Bearer ' + js["token"]
  wbs_iniflag=True
  return { 'status_code': response.status_code }


def GetEventPayload():
  """Fetch the inbound event payload for the current ACTIONID.

  Calls GET /v1/rtevent/{actionId}.

  Returns:
      dict: {'status_code': 200, 'payload': ...} on success, 603 if Init
            was not called, or an HTTP/API error dict.
  """
  if not wbs_iniflag :
     return { 'status_code':603, 'error':'Init required' }
  response = requests.get(wbs_url + '/v1/rtevent/' + wbs_actionid, headers=wbs_headers)

  if response.status_code >= 400:
    try:
      js = response.json()
    except :
      return {'status_code': response.status_code, 'error': 'inaccessible'}
    return {'status_code': response.status_code, 'error': js}

  js=response.json()
  return { 'status_code': response.status_code, 'payload':js["payload"] }


def PutStepPayload(payload):
  """Store the output payload for the current step.

  Posts to /v1/rtstep/payload using ACTIONID and STEPNAME from the environment.

  Args:
      payload: JSON-serializable step output (dict, list, etc.).

  Returns:
      dict: {'status_code': 200} on success, 603 if Init was not called,
            or an HTTP/API error dict.
  """
  if not wbs_iniflag :
     return { 'status_code':603, 'error':'Init required' }
  todo = { "actionId": wbs_actionid, "stepname": wbs_step, "payload":  payload }
  response = requests.post(wbs_url + '/v1/rtstep/payload', data=json.dumps(todo), headers=wbs_headers)

  if response.status_code >= 400:
    try:
      js = response.json()
    except :
      return {'status_code': response.status_code, 'error': 'inaccessible'}
    return {'status_code': response.status_code, 'error': js}

  return { 'status_code': response.status_code }


def GetStepPayload(stepname):
  """Retrieve a prior step's stored payload for the current ACTIONID.

  Calls GET /v1/rtstep/payload/{actionId}/{stepname}.

  Args:
      stepname: Name of the step whose payload should be fetched.

  Returns:
      dict: {'status_code': 200, 'payload': ...} on success, 603 if Init
            was not called, or an HTTP/API error dict.
  """
  if not wbs_iniflag :
     return { 'status_code':603, 'error':'Init required' }
  response = requests.get(wbs_url + '/v1/rtstep/payload/' + wbs_actionid + "/" + stepname, headers=wbs_headers)

  if response.status_code >= 400:
    try:
      js = response.json()
    except :
      return {'status_code': response.status_code, 'error': 'inaccessible'}
    return {'status_code': response.status_code, 'error': js}

  js=response.json()
  return { 'status_code': response.status_code, 'payload':js["payload"] }


def GetKeystore(keylist):
  """Fetch one or more secrets from the Collector keystore.

  Calls GET /v1/keystore/{keys} where keys is a comma-separated list.

  Args:
      keylist: Comma-separated keystore key names (spaces are stripped).

  Returns:
      dict: {'status_code': 200, 'answer': {...}} on success, 603 if Init
            was not called, 605 if a requested key is missing, or an
            HTTP/API error dict.
  """
  if not wbs_iniflag :
     return { 'status_code':603, 'error':'Init required' }
  keys=keylist.replace(' ','')
  response = requests.get(wbs_url + '/v1/keystore/' + keys, headers=wbs_headers)

  if response.status_code >= 400:
    try:
      js = response.json()
    except :
      return {'status_code': response.status_code, 'error': 'inaccessible'}
    return {'status_code': response.status_code, 'error': js}

  js=response.json()
  for key in keys.split(','):
    if not key in js:
      return { 'status_code': 605, 'error': key + ' not found' }
  return { 'status_code': response.status_code, 'answer':js }
