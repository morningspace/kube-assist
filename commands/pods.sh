#!/bin/bash

. $(dirname $(dirname $0))/utils.sh

function list_failed_pods {
  local namespace
  local all_namespaces
  local restarts_cap
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    -A|--all-namespaces)
      all_namespaces=1; shift ;;
    -r|--restarts)
      restarts_cap=$2; shift 2 ;;
    *)
      shift ;;
    esac
  done

  local scope
  local ns_flag
  local pods_file
  if [[ -n $namespace ]]; then
    scope="$namespace namespace"
    ns_flag="-n $namespace"
    pods_file=$HOME/.ka/$namespace.pods
  elif [[ -n $all_namespaces ]]; then
    scope="all namespaces"
    ns_flag="--all-namespaces"
    pods_file=$HOME/.ka/all.pods
  else
    scope="$(kubectl config view --minify --output 'jsonpath={..namespace}') namespace"
    pods_file=$HOME/.ka/pods
  fi

  logger::info "Checking pods in $scope..."

  kubectl get pod $ns_flag 2>/dev/null >$pods_file || return 1

  local parts
  local ready
  local status
  local restarts
  local containers_total
  local containers_running
  local line_num=0
  local failed_pods_lines=()

  while IFS= read -r pod_line; do
    (( line_num++ )); (( line_num == 1 )) && failed_pods_lines+=("$pod_line") && continue

    parts=($pod_line)

    if [[ $scope == "all namespaces" ]]; then
      ready=${parts[2]}
      status=${parts[3]}
      restarts=${parts[4]}
    else
      ready=${parts[1]}
      status=${parts[2]}
      restarts=${parts[3]}
    fi
    
    containers_total=${ready#*/}
    containers_running=${ready%/*}

    local is_pod_failed=0

    if (( $containers_running == $containers_total )); then
      [[ $status != Completed && $status != Running ]] && is_pod_failed=1
    else
      [[ $status != Completed ]] && is_pod_failed=1
    fi

    (( restarts > restarts_cap && restarts_cap != 0 )) && is_pod_failed=1

    if [[ $is_pod_failed == 1 ]]; then
     failed_pods_lines+=("$pod_line")
    fi
  done < "$pods_file"

  if [ ${#failed_pods_lines[@]} -le 1 ]; then
    logger::info "No failed resources found in $scope."
  else
    logger::warn "Some failed resources found in $scope."
    for failed_pod_line in "${failed_pods_lines[@]}"; do
      echo "$failed_pod_line"
    done
  fi
}

function help {
  echo "
Kuberntes Command Line Assistant: Pods

List all pods that failed to run or are not healthy

Usage:
  $(dirname $(dirname $0))/ka.sh pods|pod|po [options]
  $0 [options]

Options:
  -n|--namespace <ns>   List failed pods in a particular namespace
  -A|--all-namespaces   List failed pods in all namespaces
  -r|--restarts <num>   Take pod restarted more than <num> times as failed case
  -h|--help             Print the help information
"
}

handle=list_failed_pods

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) handle=help; shift ;;
    *)  POSITIONAL+=("$1"); shift ;;
  esac
done

${handle} ${POSITIONAL[@]}
