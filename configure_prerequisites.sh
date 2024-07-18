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
  echo 'No config file found. Exiting'
  exit 1
fi
printf "${BLUE}Found environment config file %s${NORMAL}\n" $ENV_FILE

## Configure variables used in this script
printf "${BLUE}Reading environment config file %s${NORMAL}\n" $ENV_FILE
set -o allexport
source .env
set +o allexport

## Configure MariaDB
if [[ -z ${AWS_RDB_DOMAIN} ]]; then
  printf "${BLUE}Configuring database server with database and admin user${NORMAL}\n"
  cat <<EOF | sudo -u mysql mysql
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
exit
EOF
else
  printf "${BLUE}Configuring database server with database and admin user${NORMAL}\n"
  cat <<EOF | MYSQL_PWD=$DB_ROOT_PASS mysql -h $DB_HOST -u $DB_ROOT_USER
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
exit
EOF
fi

## Configure PHP
printf "${BLUE}Configuring PHP${NORMAL}\n"
sudo sed -i 's/user = www-data/user = nginx/' /etc/php/8.2/fpm/pool.d/www.conf
sudo sed -i 's/group = www-data/group = nginx/' /etc/php/8.2/fpm/pool.d/www.conf
sudo sed -i 's/listen.owner = www-data/listen.owner = nginx/' /etc/php/8.2/fpm/pool.d/www.conf
sudo sed -i 's/listen.group = www-data/listen.group = nginx/' /etc/php/8.2/fpm/pool.d/www.conf
sudo systemctl restart php8.2-fpm

## Configure PHP-FPM
printf "${BLUE}Configuring PHP-FPM${NORMAL}\n"
sudo sed -i 's/max_execution_time = 30/max_execution_time = 180/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/max_execution_time = 30/max_execution_time = 180/' /etc/php/8.2/cli/php.ini
sudo sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 25M/g' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = 8M/post_max_size = 25M/g' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/zlib.output_compression = Off/zlib.output_compression = On/g' /etc/php/8.2/fpm/php.ini
sudo chgrp -R nginx /var/lib/php/sessions
sudo systemctl restart php8.2-fpm

## Configure SSL
printf "${BLUE}Configuring SSL${NORMAL}\n"
if !(sudo [ -f /etc/letsencrypt/live/${FQDN}/cert.pem ] ); then
  sudo certbot certonly --nginx --agree-tos --no-eff-email --staple-ocsp --preferred-challenges http -m $ADMIN_EMAIL -d $FQDN
  sudo openssl dhparam -dsaparam -out /etc/ssl/certs/dhparam.pem 4096
else
  printf "${MAGENTA}Not requesting certificate - /etc/letsencrypt/live/%s/cert.pem exists${NORMAL}\n" "${FQDN}"
fi
sudo certbot renew --dry-run

## Configure nginx
printf "${BLUE}Configuring nginx${NORMAL}\n"
sudo mkdir $WWW_ROOT -p
sudo cp nginx.conf.sample $WWW_ROOT/
sudo chown -R $USER:nginx $WWW_ROOT
cat <<EOF | sudo tee /etc/nginx/conf.d/mautic.conf > /dev/null
#upstream fastcgi_backend {
#  server  unix:/run/php/php8.2-fpm.sock;
#}

server {
    if (\$host = $FQDN) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot


  # Redirect any http requests to https
  listen 80;
  listen [::]:80;
  server_name $FQDN;
  return 301 https://\$host\$request_uri;


}


server {
  listen 443 ssl; # managed by Certbot
  listen [::]:443 ssl; # managed by Certbot
  server_name $FQDN;

  set \$MAUTIC_ROOT $WWW_ROOT;
  include $WWW_ROOT/nginx.conf.sample;
  client_max_body_size 4M;
  client_body_buffer_size 128k;

  access_log /var/log/nginx/mautic.access.log;
  error_log  /var/log/nginx/mautic.error.log;

  # TLS configuration
  ssl_certificate /etc/letsencrypt/live/$FQDN/fullchain.pem; # managed by Certbot
  ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem; # managed by Certbot
  ssl_trusted_certificate /etc/letsencrypt/live/$FQDN/chain.pem;
  ssl_protocols TLSv1.2 TLSv1.3;

  ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384';
  ssl_prefer_server_ciphers on;
  ssl_session_cache shared:SSL:50m;
  ssl_session_timeout 1d;

  # OCSP Stapling ---
  # fetch OCSP records from URL in ssl_certificate and cache them
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_dhparam /etc/ssl/certs/dhparam.pem;
}
EOF

sudo nginx -t
sudo systemctl restart nginx

printf "${POWDER_BLUE}Completed %s${NORMAL}\n" $0
