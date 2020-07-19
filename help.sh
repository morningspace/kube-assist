#!/bin/bash

function usage {
  echo "
Extended Kuberntes Command Line

Usage:
  $0 [command] [options]

Commands:
  context   Provide menu to switch Kubernetes context and add note to context
  cert      Detect whether the cluster certificate is expired or not
  pods      Detect whether there are pods failed to launch
"
}

usage
