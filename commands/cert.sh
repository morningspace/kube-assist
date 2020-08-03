#!/bin/bash

. $(dirname $(dirname $0))/utils.sh

function parse_apiserver {
  logger::info 'Detecting API server host and port ...'
  local context=$(kubectl config current-context)
  local cluster=$(kubectl config get-contexts $context --no-headers | awk '{print $3}')
  local host=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$cluster\")].cluster.server}")
  server_host=$(echo ${host%:*} | sed -e "s%^https://%%")
  server_port=$(echo ${host##*:})
  logger::info "Server host: $server_host"
  logger::info "Server port: $server_port"
}

function check_certificate {
  parse_apiserver

  logger::info 'Checking if the API certificate is expired or not ...'

  echo | openssl s_client -servername $server_host -connect $server_host:$server_port 2>/dev/null | openssl x509 -noout -dates
  if [ $now -ge $notBefore ];
  then
    logger::info 'The API certificate is not expired'
  else
    logger::error 'The API certificate has been expired'
  fi
}

function help {
  echo "
Kuberntes Command Line Assistant: Cert

Detect whether the API certificate is expired or not

Usage:
  $(dirname $(dirname $0))/ka.sh cert [options]
  $0 [options]

Options:
  -h|--help             Print the help information
"
}

handle=check_certificate

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) handle=help; shift ;;
    *)  POSITIONAL+=("$1"); shift ;;
  esac
done

${handle} ${POSITIONAL[@]}
