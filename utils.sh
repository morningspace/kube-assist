CYAN="\033[0;36m"
NORMAL="\033[0m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
WHITE="\033[0;37m"

function logger::info {
  printf "${CYAN}INFO ${NORMAL} $@\n"
}

function logger::warn {
  printf "${YELLOW}WARN ${NORMAL} $@\n"
}

function logger::error {
  printf "${RED}ERROR${NORMAL} $1\n"
}

mkdir -p $HOME/.ka

function on_exit {
  rm -rf $HOME/.ka
}

trap on_exit exit
