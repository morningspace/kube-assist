#!/bin/bash

command_name=${1:-help}

case $command_name in
  context|pods|logs|cert|dump|help) ;;
  ctx)    command_name="context"    ;;
  pod|po) command_name="pods"       ;;
  log)    command_name="logs"       ;;
  *)      echo 'Argument "'$command_name'" not known.'
          command_name="help"       ;;
esac

command_script=$(dirname $0)/commands/$command_name.sh
if [[ -x $command_script ]]; then
  $command_script ${@:2}
else
  echo 'File "'$command_script'" not found or not excutable.'
fi
