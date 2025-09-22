#!/bin/bash

# Using acme.sh to get ssl certs 
# Docs: https://github.com/acmesh-official/acme.sh

source ./exports.sh

./install_nginx.sh


cd $HOME
git clone https://github.com/acmesh-official/acme.sh.git
cd ./acme.sh
./acme.sh --install -m $EMAIL

./acme.sh --issue -d $SERVER_NAME -w /usr/share/nginx/html --debug 2 --server letsencrypt

./acme.sh --install-cert -d $SERVER_NAME --reloadcmd "service nginx force-reload"

./acme.sh --install-cert -d $SERVER_NAME \
--key-file /etc/letsencrypt/live/$SERVER_NAME/privkey.pem \
--fullchain-file /etc/letsencrypt/live/$SERVER_NAME/fullchain.pem \
--reloadcmd "sudo service nginx force-reload"


./install_nginx_ssl.sh

echo "Succesfully installed NGINX with SSL"
