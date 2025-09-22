#!/bin/bash
source ./exports.sh

# Override nginx conf to use SSL certs
cat > $HOME/nginx_conf_temp << EOF
server {
  listen 80;
  listen [::]:80;
  server_name $(echo $SERVER_NAME);

  listen [::]:443 ssl ipv6only=on;
  listen 443 ssl;
  ssl_certificate /etc/letsencrypt/live/$(echo $SERVER_NAME)/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$(echo $SERVER_NAME)/privkey.pem;

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
}
EOF

sudo mv $HOME/nginx_conf_temp /etc/nginx/sites-enabled/default

sudo ufw allow "Nginx Full"
sudo ufw allow https
sudo ufw enable

sudo service nginx restart

./nginx_harden.sh
