#!/bin/bash

. $(dirname $0)/logs.sh

function parse_apiserver {
  logger::info 'Detect API server name and port...'
  local context=$(kubectl config current-context)
  local cluster=$(kubectl config get-contexts $context --no-headers | awk '{print $3}')
  local server=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$cluster\")].cluster.server}")
  server_name=$(echo ${server%:*} | sed -e "s%^https://%%")
  server_port=$(echo ${server##*:})
  logger::info "Server name: $server_name"
  logger::info "Server port: $server_port"
}

function check_cert {
  logger::info 'Check if the cluster certificate is expired...'

  echo | openssl s_client -servername $server_name -connect $server_name:$server_port 2>/dev/null | openssl x509 -noout -dates
  if [ $now -ge $notBefore ];
  then
    logger::info 'The cluster certificate has not bean expired'
  else
    logger::error 'The cluster certificate has been expired'
  fi
}

parse_apiserver
check_cert
