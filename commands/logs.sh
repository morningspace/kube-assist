#!/bin/bash

. $(dirname $(dirname $0))/utils.sh

function next_color {
  local skip_colors="1,2,8,10"
  local candidate_color=$(($1+1))
  [[ $skip_colors =~ (^|,)$candidate_color($|,) ]] && echo `next_color $candidate_color` || echo $candidate_color
}

function join() {
  # $1 is sep
  # $2... are the elements to join
  local sep=$1 ret=$2
  shift 2 || shift $(($#))
  printf "%s" "$ret${@/#/$sep}"
}

function print_logs {
  # Allows for more colors, this is useful if one tails a lot pods
  export TERM=xterm-256color

  local namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
  local since="0s"
  local tail="-1"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    -s|--since)
      [ -n "$2" ] && since="$2"; shift 2 || shift ;;
    --tail)
      [ -n "$2" ] && tail="$2"; shift 2 || shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local all_pods=($(kubectl get pods -n $namespace ${POSITIONAL[@]} --output=jsonpath='{.items[*].metadata.name}'))
  local all_containers=$(kubectl get pods -n $namespace -o=jsonpath="{range .items[*]}{.metadata.name} {.spec['containers', 'initContainers'][*].name} \n{end}")

  local color_index=0
  local color_start
  local color_end=$(tput sgr0)
  local display_name

  local cmd_logs=()
  local cmd_to_tail

  for pod in ${all_pods[@]}; do
    local pod_containers=($(echo -e "$all_containers" | grep $pod | cut -d ' ' -f2- | xargs -n1))
    for container in ${pod_containers[@]}; do
      if [ ${#all_pods[@]} -eq 1 -a ${#pod_containers[@]} -eq 1 ]; then
        color_start=$(tput sgr0)
      else
        color_index=$(next_color $color_index)
        color_start=$(tput setaf $color_index)
      fi

      if [ ${#pod_containers[@]} -eq 1 ]; then
        display_name="${pod}"
      else
        display_name="${pod} ${container}"
      fi

      local cmd_kubectl="kubectl logs $pod $container -n $namespace --since=$since --tail=$tail"
      local colored_line="${color_start}[$display_name] \$REPLY ${color_end}"
      local cmd_colorify_lines='while read -r; do echo "'$colored_line'" | tail -n +1; done'
      cmd_logs+=("$cmd_kubectl | $cmd_colorify_lines");
    done
  done

  # Join all log commands into one string separated by " & "
  cmd_to_tail=$(join " & " "${cmd_logs[@]}")

  # Aggregate all logs and print to stdout
  tail -n +1 <( eval "$cmd_to_tail" )
}

function help {
  echo "
Kuberntes Command Line Assistant: Logs

Print logs for multiple pods in a particular namespace using different colors

Usage:
  $(dirname $(dirname $0))/ka.sh logs|logs [options]
  $0 [options]

Options:
  -n|--namespace <ns>   Print pods logs in the specified namespace
  -s|--since <duration> Only return logs newer than a relative duration like 5s, 2m, or 3h. Defaults to all logs
  --tail                Lines of recent log file to display. Defaults to -1, showing all log lines
  -h|--help             Print the help information
"
}

handle=print_logs

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) handle=help; shift ;;
    *)  POSITIONAL+=("$1"); shift ;;
  esac
done

${handle} ${POSITIONAL[@]}
