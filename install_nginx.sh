#!/bin/bash
source ./exports.sh

echo "Installing NGINX... Relies on SERVER_NAME => $SERVER_NAME & LOGIN_UNAME => $LOGIN_UNAME"
# install nginx and tools
sudo apt-get install nginx apache2-utils snapd -y

cat > $HOME/nginx_conf_temp << EOF
server {
  listen 80;
  listen [::]:80;
  server_name $(echo $SERVER_NAME);

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
sudo ufw enable

sudo service nginx restart

./nginx_harden.sh
