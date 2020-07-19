#!/bin/bash

. $(dirname $0)/logs.sh

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

  local ns_arg
  if [[ -z $namespace ]]; then
    scope="all namespaces"
    ns_arg="--all-namespaces"
  else
    scope="namespace $namespace"
    ns_arg="-n $namespace"
  fi

  logger::info "List pods in $scope..."
  pods_info=($(kubectl get pod $ns_arg | tail -n +2))
}

function check_pods {
  logger::info "Checking pods in $scope..."
  local pod_num=${#pods_info[@]}

  local step=5
  local namespace
  local name
  local ready
  local status
  local restarts

  if [[ $scope == "all namespaces" ]]; then
    step=6
  fi

  for (( i = 0; i < pod_num; i += step )); do
    if [[ $scope == "all namespaces" ]]; then
      namespace=${pods_info[i]}
      name=${pods_info[i+1]}
      ready=${pods_info[i+2]}
      status=${pods_info[i+3]}
      restarts=${pods_info[i+4]}
    else
      namespace=${scope#namespace }
      name=${pods_info[i]}
      ready=${pods_info[i+1]}
      status=${pods_info[i+2]}
      restarts=${pods_info[i+3]}
    fi

    local containers_total=${ready#*/}
    local containers_running=${ready%/*}
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
