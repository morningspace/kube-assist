#!/bin/bash

mkdir -p $HOME/.kube
touch $HOME/.kube/context-credentials

function pick_context {
  local ctx_list=($(kubectl config get-contexts -oname))
  current_ctx=$(kubectl config current-context)

  for ((i = 0; i < ${#ctx_list[@]}; i ++)); do
    local is_current_ctx=0
    if [[ $current_ctx == ${ctx_list[$i]} ]]; then
      is_current_ctx=1
    fi

    if cat $HOME/.kube/context-credentials | grep -q ${ctx_list[$i]}; then
      local entry=($(cat $HOME/.kube/context-credentials | grep ${ctx_list[$i]}))
      local note=$(echo ${entry[2]} | base64 -d)
      [[ -n $note ]] && ctx_list[$i]="${ctx_list[$i]} ($note)"
    fi

    if [[ $is_current_ctx == 1 ]]; then
      ctx_list[$i]="${ctx_list[$i]} *"
    fi
  done

  printf "\033[0;36m? \033[0;37mWhich context do you want to pick up:\033[0m \n"
  COLUMNS=1
  PS3="Choose a number: "
  select ctx in "${ctx_list[@]}"; do
    case $ctx in
    *)
      ctx=${ctx%% *}
      if [[ -n $ctx && "${ctx_list[@]}" =~ $ctx ]]; then
        kubectl config use $ctx
        current_ctx=$(kubectl config current-context)
        break
      else
        printf "Invalid option $REPLY\n"
      fi;;
    esac
  done
}

function auth_context {
  # kubectl get users.user.openshift.io >/null 2>&1 || return
  [[ $current_ctx =~ kind- ]] && return
  
  local user_input=0
  if cat $HOME/.kube/context-credentials | grep -q $current_ctx; then
    local entry=($(cat $HOME/.kube/context-credentials | grep $current_ctx))
    local credential=($(echo ${entry[1]} | base64 -d))
    username=${credential[0]}
    password=${credential[1]}
    if [[ -z $username || -z $password ]]; then
      user_input=1
    fi
  else
    user_input=1
  fi

  printf "Find authenticated user: "
  if ! oc whoami ; then
    if [[ $user_input == 1 ]]; then
      echo -n -e "\033[0;36m? \033[0;37mUsername: \033[0m"
      read -r username
      echo -n -e "\033[0;36m? \033[0;37mPassword: \033[0m"
      read -s password
      echo
    fi

    oc login -u $username -p $password
  fi
}

function note_context {
  echo -n -e "\033[0;36m? \033[0;37mAdd a note or press Enter to skip: \033[0m"
  read -r note
}

function save_context {
  local credential=$(echo "$username $password" | base64 -w 0)
  local context_info="$current_ctx $credential"
  if [[ -z $note ]]; then
    if cat $HOME/.kube/context-credentials | grep -q $current_ctx; then
      local entry=($(cat $HOME/.kube/context-credentials | grep $current_ctx))
      note=${entry[2]}
    fi
  else
    note=$(echo $note | base64 -w 0)
  fi
  context_info="$context_info $note"

  if cat $HOME/.kube/context-credentials | grep -q $current_ctx; then
    cat ~/.kube/context-credentials | sed "s#^$current_ctx.*#$context_info#" > ~/.kube/context-credentials.tmp
    mv ~/.kube/context-credentials{.tmp,}
  else
    echo "$context_info" >> $HOME/.kube/context-credentials
  fi
}

pick_context
auth_context
note_context
save_context
