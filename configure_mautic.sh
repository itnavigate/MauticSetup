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

cd $WWW_ROOT
sudo find . -type f -not -perm 644 -exec chmod 644 {} +
sudo find . -type d -not -perm 755 -exec chmod 755 {} +
sudo chmod -R g+w var/cache/ var/logs/ app/config/
sudo chmod -R g+w media/files/ media/images/ translations/
sudo rm -rf var/cache/*
sudo chown -R nginx:nginx $WWW_ROOT

sudo -u nginx php ./bin/console mautic:install $FQDN \
 --db_host=$DB_HOST \
 --db_port=$DB_PORT \
 --db_name=$DB_NAME \
 --db_user=$DB_USER \
 --db_password=$DB_PASS \
 --admin_firstname=$ADMIN_FIRSTNAME \
 --admin_lastname=$ADMIN_LASTNAME \
 --admin_username=$ADMIN_USER \
 --admin_email=$ADMIN_EMAIL \
 --admin_password=$ADMIN_PASSWORD
# --mailer_from_name=$MAILER_FROM_NAME \
# --mailer_from_email=$MAILER_FROM_EMAIL \
# --mailer_transport=$MAILER_TRANSPORT \
# --mailer_host=$MAILER_HOST \
# --mailer_port=$MAILER_PORT \
# --mailer_user=$MAILER_USER \
# --mailer_password=$MAILER_PASSWORD \
# --mailer_encryption=$MAILER_ENCRYPTION \
# --mailer_auth_mode=$MAILER_AUTH_MODE \

# --db_table_prefix=DB_TABLE_PREFIX        Database tables prefix.
# --db_backup_tables=DB_BACKUP_TABLES      Backup database tables if they exist; otherwise drop them. [default: true]
# --db_backup_prefix=DB_BACKUP_PREFIX      Database backup tables prefix. [default: "bak_"]
# --mailer_spool_type=MAILER_SPOOL_TYPE    Spool mode (file|memory).
# --mailer_spool_path=MAILER_SPOOL_PATH    Spool path.

