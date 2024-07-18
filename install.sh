#!/bin/bash

if [[ -d /home/colin/.npm-global ]]; then
  NEW_NPN=false
else
  NEW_NPN=true
fi
bash ./install_prerequisites.sh
if [[ $NEW_NPM = "true" ]]; then
  echo "Initial setup done - restart install script"
  . ~/.profile
  
fi
read -t 10 -p "About to configure prerequisites. Press CTRL-C to stop, or ENTER to continue immediately." reply
echo

bash ./configure_prerequisites.sh
read -t 10 -p "About to install mautic. Press CTRL-C to stop, or ENTER to continue immediately." reply
echo

bash ./install_mautic.sh
read -t 10 -p "About to configure mautic. Press CTRL-C to stop, or ENTER to continue immediately." reply
echo

bash ./configure_mautic.sh
