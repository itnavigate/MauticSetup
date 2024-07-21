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

## Prerequisites
sudo apt install -y unzip cron

## Install MariaDB
printf "${BLUE}Installing MariaDB${NORMAL}\n"
sudo apt install -y default-mysql-client
if [[ -z ${AWS_RDB_DOMAIN} ]]; then
  sudo apt install mariadb-server
  sudo mysql_secure_installation
fi


## Install nginx
printf "${BLUE}Installing PHP${NORMAL}\n" 
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/`lsb_release -is | tr '[:upper:]' '[:lower:]'` `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
sudo apt update
sudo apt install -y nginx

## Instal PHP and its extensions
printf "${BLUE}Installing PHP${NORMAL}\n"
sudo apt install -y php8.2-{apcu,bcmath,bz2,cli,common,curl,fpm,gd,gmp,igbinary,imap,intl,mbstring,msgpack,mysql,opcache,phpdbg,readline,soap,tidy,xml,xml,xmlrpc,zip}
sudo apt install -y php-{apcu,bcmath,bz2,cli,common,curl,fpm,gd,gmp,igbinary,imap,intl,mbstring,msgpack,mysql,opcache,phpdbg,readline,soap,tidy,xml,xml,xmlrpc,zip}

## Install python3.11-venv
printf "${BLUE}Installing python3.11-venv${NORMAL}\n"
sudo apt install -y python3.11-venv

## Install SSL
printf "${BLUE}Installing SSL${NORMAL}\n" 
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

if [ $GITHUB = true ]; then
  ## Install Composer
  printf "${BLUE}Installing Composer${NORMAL}\n"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php composer-setup.php --2.7
  php -r "unlink('composer-setup.php');"
  sudo mv composer.phar /usr/local/bin/composer

  ## Install NodeJS
  NODE_MAJOR="${NODE_MAJOR:-20}"
  printf "${BLUE}Installing (and configuring) NodeJS version %s${NORMAL}\n" $NODE_MAJOR
  sudo apt install -y ca-certificates gnupg
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
  sudo apt update
  sudo apt install nodejs -y
  mkdir ~/.npm-global
  npm config set prefix '~/.npm-global'
  echo "export PATH=~/.npm-global/bin:\$PATH" >> ~/.profile
  if [[ $NEW_NPM = "true" ]]; then
    printf "${RED}**** Now run . ~/.prifile before continuing ****${NORMAL}\n"
  fi
fi;
printf "${POWDER_BLUE}Completed %s${NORMAL}\n" $0
