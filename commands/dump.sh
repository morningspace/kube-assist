#!/bin/bash

. $(dirname $(dirname $0))/utils.sh

function print_with_masks {
  local resource=$1

  if [[ $apply_mask == 1 ]]; then
    resource="$(echo "$resource" | sed 's/\(.*\)-[a-z0-9]\{10\}-[a-z0-9]\{5\}\(  *\)/\1-**********-*****\2/')"
    resource="$(echo "$resource"   | sed 's/\(.*\)-[a-z0-9]\{9\}-[a-z0-9]\{5\}\(  *\)/\1-*********-*****\2/')"
    resource="$(echo "$resource"   | sed 's/\(.*\)-job-[a-z0-9]\{5\}\(  *\)/\1-job-*****\2/')"
    resource="$(echo "$resource"   | sed 's/\(.*\)-dockercfg-[a-z0-9]\{5\}\(  *\)/\1-dockercfg-*****\2/')"
    resource="$(echo "$resource"   | sed 's/\(.*\)-token-[a-z0-9]\{5\}\(  *\)/\1-token-*****\2/')"
  fi

  echo -n "$resource"
}

function dump_in_namespace {
  local api_resources=(${POSITIONAL[@]})
  if [[ -z ${api_resources[@]} ]]; then
    api_resources=($(oc api-resources --verbs=list --namespaced -o name))
  fi

  local resource_count=0
  for api_resource in ${api_resources[@]}; do
    [[ " ${no_resources[@]} " =~ " $api_resource " ]] && continue

    local resources=($(oc get $api_resource -n $namespace -o name))
    local resource_num=${#resources[@]}
    resource_num=1
    if [[ $resource_num != 0 ]]; then
      echo "${resource_count}) oc get $api_resource -n $namespace ${kubectl_flags[@]}"
      (( resource_count++ ))

      local resource_file="$HOME/.ka/$namespace.$api_resource"
      oc get $api_resource -n $namespace ${kubectl_flags[@]} > $resource_file
      # resource_file="test.txt"

      local headline=$(cat $resource_file | head -n1)
      local lines=()
      local column_positions=()
      local column_start=0
      local column_width=0
      local column_state="word:on"
      local spaces=0
      local column_visible=()
      local column_index=0
      local column_name
      for (( pos = 0; pos < ${#headline}; pos ++ )); do
        local char=${headline:$pos:1}

        (( column_width++ ))

        if [[ $column_state == "word:on" && $char == ' ' ]]; then
          (( spaces++ ))
          column_state="word:off"
        elif [[ $column_state == "word:off" && $char == ' ' ]]; then
          (( spaces++ ))
        elif [[ $column_state == "word:off" && $char != ' ' && $spaces == 1 ]]; then
          spaces_num=0
          column_state="word:on"
        elif [[ $column_state == "word:off" && $char != ' ' && $spaces != 0 ]]; then
          (( column_width-- ))
          column_positions+=("$column_start:$column_width")

          column_name=$(echo ${headline:$column_start:$column_width})
          if [[ -n ${columns[@]} ]]; then
            [[ " ${columns[@]} " =~ " $column_name " ]] && column_visible+=($column_index)
          else
            [[ " ${no_columns[@]} " =~ " $column_name " ]] || column_visible+=($column_index)
          fi
          (( column_index++ ))

          column_start=$pos
          column_width=1
          column_state="word:on"
          spaces=0
        fi
      done
      
      column_positions+=("$column_start")
      column_name=$(echo ${headline:$column_start:$column_width})
      if [[ -n ${columns[@]} ]]; then
        [[ " ${columns[@]} " =~ " $column_name " ]] && column_visible+=($column_index)
      else
        [[ " ${no_columns[@]} " =~ " $column_name " ]] || column_visible+=($column_index)
      fi

      local column_num=$column_index

      # for p in ${column_positions[@]}; do echo "$p"; done
      # for v in ${column_visible[@]};   do echo "$v"; done

      while IFS= read -r resource_line; do
        local column_index=0
        for position in ${column_positions[@]}; do
          if [[ " ${column_visible[@]} " =~ " $column_index " ]]; then
            if (( column_index < column_num )); then
              a=${position%:*}
              b=${position#*:}
              print_with_masks "${resource_line:$a:$b}"
            else
              a=${position%:*}
              print_with_masks "${resource_line:$a}"
            fi
          fi
          (( column_index++ ))
        done
        echo
      done < "$resource_file"

      echo
    fi
  done
}

dump_in_namespace "$@"

function help {
  echo "
Kuberntes Command Line Assistant: Dump

Dump resources in a particular namespace

Usage:
  $(dirname $(dirname $0))/ka.sh dump [options]
  $0 [options]

Options:
  -n|--namespace <ns>           Specify the namespace that you want to dump
  --column <COL1,COL2,...>      Specify the columns that you want to display
  --no-column <COL1,COL2,...>   Specify the columns that you do not want to display
  --no-resource <RES1,RES2,...> Specify the resources that you do not want to dump
  --mask                        Apply mask when display the name for some resources, e.g. pod, secret, job, etc.
  -h|--help                     Print the help information
"
}

handle=dump_in_namespace

columns=()
no_columns=()
no_resources=()
kubectl_flags=()
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      handle=help; shift ;;
    -n|--namespace)
      namespace=$2; shift 2 ;;
    --column)
      IFS=',' read -a columns <<< "$2"; shift 2 ;;
    --no-column)
      IFS=',' read -a no_columns <<< "$2"; shift 2 ;;
    --no-resource)
      IFS=',' read -a no_resources <<< "$2"; shift 2 ;;
    --mask)
      apply_mask=1; shift ;;
    -o)
      kubectl_flags+=($1 $2); shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
  esac
done

${handle} "${POSITIONAL[@]}"
