#!/bin/bash

. $(dirname $0)/logs.sh

[[ -n $1 ]] && cmd=$1 || cmd="help"

if [[ -f $(dirname $0)/$cmd.sh ]]; then
  . $(dirname $0)/$1.sh
else
  logger::error "Command not recognized."
fi
