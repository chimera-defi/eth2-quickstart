#!/bin/bash

export SERVER_NAME="rpc.sharedtools.org"

# install nginx and tools
sudo apt-get install nginx apache2-utils snapd -y

# instal certbot
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

cat > $HOME/nginx_conf_temp << EOF
server {
  listen 80;
  listen [::]:80;
  server_name $(echo $SERVER_NAME);

  listen [::]:443 ssl ipv6only=on; # managed by Certbot
  listen 443 ssl; # managed by Certbot
  ssl_certificate /etc/letsencrypt/live/$(echo $SERVER_NAME)/fullchain.pem; # managed by Certbot
  ssl_certificate_key /etc/letsencrypt/live/$(echo $SERVER_NAME)/privkey.pem; # managed by Certbot
  include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

  location ^~ /ws {
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Host \$http_host;
      proxy_set_header X-NginX-Proxy true;
      proxy_pass   http://127.0.0.1:8546/;
  }

  location ^~ /rpc {
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Host \$http_host;
      proxy_set_header X-NginX-Proxy true;
      proxy_pass    http://127.0.0.1:8545/;
  }

  location ^~ /prysm/checkpt_sync {
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Host \$http_host;
      proxy_set_header X-NginX-Proxy true;
      proxy_pass   http://127.0.0.1:3500/;
  }

  location ^~ /prysm/web {
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Host \$http_host;
      proxy_set_header X-NginX-Proxy true;
      proxy_pass   http://127.0.0.1:7500/;
  }
}
EOF

cp $HOME/nginx_conf_temp /etc/nginx/sites-enabled/default


echo "For certbot to work server name records must be pre-set"
echo "Ime certbot breaks the nginx config so we do it manually"
echo "We will now prompt you to go through ssl certbot challenge for your domain"

# sudo certbot --nginx -v
sudo certbot certonly --manual --preferred-challenges dns
