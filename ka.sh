#!/bin/bash

command_name=${1:-help}

case $command_name in
  context|pods|help) ;;
  ctx) command_name="context" ;;
  pod|po) command_name="pods" ;;
  log) command_name="logs" ;;
  *)
    echo 'Argument "'$command_name'" not known.'
    command_name="help" ;;
esac

command_file=$(dirname $0)/commands/$command_name.sh

[[ -f $command_file ]] && $command_file
