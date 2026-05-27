#!/bin/bash

c_auth="curl -s '$CA_WBS_URL/v1/auth/apicode' -X 'POST' -H 'Environment:$ENV' -H 'Content-Type:application/json' -d '{ \"apiCode\": \"$CA_ACCESS_CODE\" }'"
answ1=`bash -c "$c_auth"`
token=`jq -r .token <<< $answ1`
if [ $token = null ]; then
  echo $answ1
  exit 4
fi

c_getks="curl -s '$CA_WBS_URL/v1/keystore/$order' -H 'Environment:$ENV' -H 'Content-Type:application/json' -H 'Authorization:Bearer $token'"
answ2=`bash -c "$c_getks"`

IFS=','
read -a strarr <<< "$order"
n=1
for val in "${strarr[@]}";
do
  key_value[$n]=`jq -r .$val <<<$answ2`
  let n=$n+1
done
