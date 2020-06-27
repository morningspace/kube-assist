#!/bin/bash

if [[ -z $SERVER_NAME ]]; then
  context=$(oc config current-context)
  cluster=$(oc config get-contexts $context --no-headers | awk '{print $3}')
  server=$(oc config view -o jsonpath="{.clusters[?(@.name == \"$cluster\")].cluster.server}")

  SERVER_NAME=$(echo ${server%:*} | sed -e "s%^https://%%")
  SERVER_PORT=$(echo ${server##*:})
fi

SERVER_PORT=${SERVER_PORT:-6443}

echo | openssl s_client -servername $SERVER_NAME -connect $SERVER_NAME:$SERVER_PORT 2>/dev/null | openssl x509 -noout -dates
if [ $now -ge $notBefore ];
then
  echo 'OCP certificate is not expired';
else
  echo 'OCP certificate has been expired';
fi
