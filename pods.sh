#!/bin/bash

function logger::info {
  printf "\033[0;36mINFO \033[0m $@\n"
}

function logger::warn {
  printf "\033[0;33mWARN \033[0m $@\n"
}

function logger::error {
  printf "\033[0;31mERROR\033[0m $1\n"
  exit -1
}

pods_info_failed=()
pods_info=()

function get_pods {
  local namespace
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n)
      namespace=$2
      shift # past argument
      shift # past argument
      ;;
    *)      # unknown option
      POSITIONAL+=("$1") # save it in an array for later use
      shift # past argument
      ;;
    esac
  done

  if [[ -z $namespace ]]; then
    pods_info=($(oc get pod --all-namespaces | tail -n +2))
    scope="all namespaces"
  else
    pods_info=($(oc get pod    -n $namespace | tail -n +2))
    scope="namespace $NAMESPACE"
  fi
}

function check_pods {
  local pod_num=${#pods_info[@]}

  for (( i = 0; i < pod_num; i += 6 )); do
    local namespace=${pods_info[i]}
    local name=${pods_info[i+1]}
    local ready=${pods_info[i+2]}
    local containers_total=${ready#*/}
    local containers_running=${ready%/*}
    local status=${pods_info[i+3]}
    local restarts=${pods_info[i+4]}
    local pod_failed=0
    if (( $containers_running == $containers_total )); then
      [[ $status != Completed && $status != Running ]] && pod_failed=1
    else
      [[ $status != Completed ]] && pod_failed=1
    fi

    if [[ $pod_failed == 1 ]]; then
      pods_info_failed+=("$namespace $name $ready $status $restarts")
    fi
  done

  if [[ -z $pods_info_failed ]]; then
    logger::info "Congratulations! All pods in $scope are up and runing."
  else
    logger::warn "Some pods in $scope are failed to start."
    printf '%-35s %-70s %6s %20s %9s\n' 'NAMESPACE' 'NAME' 'READY' 'STATUS' 'RESTARTS'
    printf '%-35s %-70s %6s %20s %9s\n' '---------' '----' '-----' '------' '--------'
    for info in "${pods_info_failed[@]}"; do
      printf '%-35s %-70s %6s %20s %9s\n' $info
    done
  fi
}

get_pods "$@"
check_pods
