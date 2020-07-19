function logger::info {
  printf "\033[0;36mINFO \033[0m $@\n"
}

function logger::warn {
  printf "\033[0;33mWARN \033[0m $@\n"
}

function logger::error {
  printf "\033[0;31mERROR\033[0m $1\n"
  exit -1
}
