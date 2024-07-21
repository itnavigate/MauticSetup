#!/bin/bash
# From https://stackoverflow.com/questions/4332478/read-the-current-text-color-in-a-xterm/4332530#4332530
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

while [ $# -gt 0 ]; do
  case "$1" in
    --github|-g)
      GITHUB=true
    ;;
    --config*|-c*)
      if [[ "$1" != *=* ]]; then shift; fi # Value is next arg if no `=`
      ENV_FILE="${1#*=}"
      ;;
    --debug*|-d*)
      if [[ "$1" != *=* ]]; then shift; fi
      set -x
      set -v
      ;;
    --help|-h)
      printf "%s [--config|-c]=configFile\n" $0 # Flag argument
      exit 0
      ;;
    *)
      >&2 printf "${RED}Error: Invalid argument (%s)${NORMAL}\n" $1
      $0 -h
      exit 1
      ;;
  esac
  shift
done
ENV_FILE="${ENV_FILE:-.env}"
ENV_FILE="${ENV_FILE:-false}"

printf "${BLUE}Checking for existance of environment config file (%s)${NORMAL}\n" $ENV_FILE
if [[ ! -f $ENV_FILE ]]; then
  printf "${RED}Cannot find environment config file %s.\n Exiting${NORMAL}\n" $ENV_FILE
  exit 1
fi
printf "${BLUE}Found environment config file %s${NORMAL}\n" $ENV_FILE

## Configure variables used in this script
printf "${BLUE}Reading environment config file %s${NORMAL}\n" $ENV_FILE
set -o allexport
source .env
set +o allexport

if [ $GITHUB = true ]; then
  cd ~
  wget -q https://github.com/mautic/mautic/archive/refs/tags/${MAUTIC_TAG}.zip -O mautic_install_${MAUTIC_TAG}.zip
fi
cd /var/www
if [ $GITHUB = true ]; then
  sudo unzip -oqq ~/mautic_install_${MAUTIC_TAG}.zip 
  sudo mv mautic-${MAUTIC_TAG}/* mautic/
  sudo rmdir mautic-${MAUTIC_TAG}
else
  sudo unzip -oqq ~/95_mautic-510.zip -d mautic
fi
sudo chown -R $USER:nginx $WWW_ROOT
cd $WWW_ROOT
if [ $GITHUB = true ]; then
  composer update
  composer install
fi
sudo find . -type f -exec chmod g+w {} +
sudo find . -type d -exec chmod g+ws {} +
