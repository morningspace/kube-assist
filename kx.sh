#!/bin/bash

. $(dirname $0)/logs.sh

if [[ -f $(dirname $0)/$1.sh ]]; then
  . $(dirname $0)/$1.sh
else
  logger::error "Command not recognized."
fi
