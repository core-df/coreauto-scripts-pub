import os
import requests
import json

wbs_iniflag=False
wbs_env=os.environ.get('ENV')
wbs_accesscode=os.environ.get('CA_ACCESS_CODE')
wbs_url=os.environ.get('CA_WBS_URL')
wbs_headers={}


def Init():
  global wbs_headers, wbs_iniflag, wbs_url
 
  if wbs_env==None or wbs_accesscode==None or wbs_url==None :
    return { 'status_code':601, 'error':'Environment variables ENV, CA_ACCESS_CODE, CA_WBS_URL should be defined' }
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

  js=response.json()
  wbs_headers["Authorization"]= 'Bearer ' + js["token"]
  wbs_iniflag=True
  return { 'status_code': response.status_code }
    

def GetKeystore(keylist):
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

