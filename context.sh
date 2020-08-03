#!/bin/bash

. $(dirname $0)/utils.sh

CONTEXT_CREDENTIALS_FILE=$HOME/.kube/context-credentials
mkdir -p $HOME/.kube
touch $CONTEXT_CREDENTIALS_FILE

function list_context {
  contexts=($(kubectl config get-contexts -oname))
  num_of_contexts=${#contexts[@]}
  current_context=$(kubectl config current-context)

  printf "Contexts:\n\n"

  for (( i = 0; i < num_of_contexts; i ++ )); do
    local context=${contexts[i]}
    local display_name="$context"

    if cat $CONTEXT_CREDENTIALS_FILE | grep -q $context; then
      local entry=($(cat $CONTEXT_CREDENTIALS_FILE | grep $context))
      local note=$(echo ${entry[2]} | base64 -d)
      [[ -n $note ]] && display_name="$display_name ($note)"
    fi

    if [[ $context == $current_context ]]; then
      printf "%4s) ${CYAN}%s${NORMAL}\n" $i "$display_name *"
    else
      printf "%4s) %s\n" $i "$display_name"
    fi
  done

  printf "\n"
}

function pick_context {
  local num

  while true; do
    printf "${CYAN}? ${WHITE}Input the number to choose the context you want to switch to:${NORMAL} "
    read -r num

    if [[ -z $num ]]; then
      printf "No change has been made, keep using $current_context.\n\n"
      break
    fi

    if (( num >= 0 && num < num_of_contexts )); then
      kubectl config use ${contexts[num]}
      current_context=$(kubectl config current-context)
      printf "\n"
      break
    else
      printf "Please input a valid number.\n"
    fi
  done
}

function auth_context {
  local no_auth=0
  local input_credential=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-auth) no_auth=1; shift ;;
      --refresh-auth) input_credential=1; shift ;;
      *) shift ;;
    esac
  done

  [[ $no_auth == 1 || $current_context =~ kind- ]] && return

  if [[ $input_credential == 0 ]] && cat $CONTEXT_CREDENTIALS_FILE | grep -q $current_context; then
    local entry=($(cat $CONTEXT_CREDENTIALS_FILE | grep $current_context))
    local credential=($(echo ${entry[1]} | base64 -d))
    username=${credential[0]}
    password=${credential[1]}
    [[ -z $username || -z $password ]] && input_credential=1
  fi

  if [[ $input_credential == 1 ]]; then
    printf "${CYAN}? ${WHITE}Username: ${NORMAL}"
    read -r username
    printf "${CYAN}? ${WHITE}Password: ${NORMAL}"
    read -s password
    printf "\n"
  fi

  printf "Check if user has logged in ... "

  if oc whoami; then
    printf "\n"
  else
    printf "\n"
    oc login -u $username -p $password || return 1
  fi
}

function note_context {
  printf "${CYAN}? ${WHITE}Add a note or press Enter to skip: ${NORMAL}"
  read -r note
}

function save_context {
  local credential=$(echo "$username $password" | base64 -w 0)
  local context_info="$current_context $credential"
  if [[ -z $note ]]; then
    if cat $CONTEXT_CREDENTIALS_FILE | grep -q $current_context; then
      local entry=($(cat $CONTEXT_CREDENTIALS_FILE | grep $current_context))
      note=${entry[2]}
    fi
  else
    note=$(echo $note | base64 -w 0)
  fi
  context_info="$context_info $note"

  if cat $CONTEXT_CREDENTIALS_FILE | grep -q $current_context; then
    cat ~/.kube/context-credentials | sed "s#^$current_context.*#$context_info#" > ~/.kube/context-credentials.tmp
    mv ~/.kube/context-credentials{.tmp,}
  else
    echo "$context_info" >> $CONTEXT_CREDENTIALS_FILE
  fi
}

function change_context {
  list_context
  pick_context
  auth_context $@ && note_context && save_context
}

function delete_context {
  list_context

  local num
  while true; do
    printf "${CYAN}? ${WHITE}Input the number to choose the context you want to delete:${NORMAL} "
    read -r num

    if [[ -z $num ]]; then
      kubectl config delete-context $current_context
      break
    fi

    if (( num >= 0 && num < num_of_contexts )); then
      kubectl config delete-context ${contexts[num]}
      break
    else
      printf "Please input a valid number.\n"
    fi
  done
}

handle=list

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l) handle=list; shift ;;
    -c) handle=change; shift ;;
    -d) handle=delete; shift ;;
    *)  POSITIONAL+=("$1"); shift ;;
  esac
done

${handle}_context ${POSITIONAL[@]}
