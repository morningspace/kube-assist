#!/bin/bash

#
# Namespaces:
#
# ibm-common-services
# kube-system
# management-infrastructure-management (Infrastructure Management module)
# management-operations (Operations module)
# management-security-services (Security Services module)
# management-monitoring (Monitoring module)
#
pods_info_failed=()

if [[ -z $NAMESPACE ]]; then
  pods_info=($(oc get pod --all-namespaces | tail -n +2))

  n=${#pods_info[@]}

  for (( i=0; i<n; i+=6 ))
  do
    pod_containers=${pods_info[i+2]}
    pod_containers_total=${pod_containers#*/}
    pod_containers_running=${pod_containers%/*}
    if (( $pod_containers_running == $pod_containers_total )); then
      pod_status=${pods_info[i+3]}
    else
      pod_status=${pods_info[i+3]}
      if [[ $pod_status != Completed ]]; then
        pods_info_failed+=("${pods_info[i]} ${pods_info[i+1]} $pod_containers $pod_status")
      fi
    fi
  done

  if [[ -z $pods_info_failed ]]; then
    echo "Congratulations! All pods in all namespace are up and runing."
  else
    echo "Unfortunately, some pods in all namespaces are unhealthy."
    printf '%-40s %-80s %10s %10s\n' 'NAMESPACE' 'NAME' 'READY' 'STATUS'
    printf '%-40s %-80s %10s %10s\n' '---------' '----' '-----' '------'
    for info in "${pods_info_failed[@]}"; do
      printf '%-40s %-80s %10s %10s\n' $info
    done
  fi
else
  pods_info=($(oc get pod -n $NAMESPACE | tail -n +2))

  n=${#pods_info[@]}

  for (( i=0; i<n; i+=5 ))
  do
    pod_containers=${pods_info[i+1]}
    pod_containers_total=${pod_containers#*/}
    pod_containers_running=${pod_containers%/*}
    if (( $pod_containers_running == $pod_containers_total )); then
      pod_status=${pods_info[i+2]}
    else
      pod_status=${pods_info[i+2]}
      if [[ $pod_status != Completed ]]; then
        pods_info_failed+=("${pods_info[i]} $pod_containers $pod_status")
      fi
    fi
  done

  if [[ -z $pods_info_failed ]]; then
    echo "Congratulations! All pods in namespace $NAMESPACE are up and runing."
  else
    echo "Unfortunately, some pods in namespace $NAMESPACE are unhealthy."
    printf '%-40s %-80s %10s %10s\n' 'NAMESPACE' 'NAME' 'READY' 'STATUS'
    printf '%-40s %-80s %10s %10s\n' '---------' '----' '-----' '------'
    for info in "${pods_info_failed[@]}"; do
      printf '%-40s %-80s %10s %10s\n' $info
    done
  fi
fi
