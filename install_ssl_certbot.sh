#!/bin/bash
source ./exports.sh

./install_nginx.sh

# instal certbot
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

echo "For certbot to work server name records must be pre-set"
echo "Ime certbot breaks the nginx config so we do it manually"
echo "We will now prompt you to go through ssl certbot challenge for your domain"

certbot certonly --manual --preferred-challenges dns
echo "Running certbot --nginx ; This is expected to fail but will generate needed files"
certbot --nginx -d $SERVER_NAME

./install_nginx_ssl.sh
