#!/bin/sh

DOMAIN=$1

sudo apt-get -y update
sudo apt install -y nginx
sudo rm -rf /etc/nginx/sites-available/default
sudo rm -rf /etc/nginx/sites-enabled/default
echo "Nginx installed!"

sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable
echo "Firewall enabled!"

sudo cat > /tmp/nginx-conf << EOM 
server {
     listen [::]:80;
     listen 80;

     server_name $DOMAIN;

     return 301 https://$DOMAIN\$request_uri;
 }

server {
     listen [::]:443 ssl;
     listen 443 ssl;

     server_name $DOMAIN;

     ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
     ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

     location / {
        
        proxy_set_header        Host \$host:\$server_port;
        proxy_set_header        X-Real-IP \$remote_addr;
        proxy_set_header        X-Forwarded-Proto \$scheme;

        proxy_pass             http://127.0.0.1:8080;
        proxy_redirect         http://127.0.0.1:8080 https://$DOMAIN;
     } 
 }
EOM

sudo cp /tmp/nginx-conf /etc/nginx/sites-available/$DOMAIN
sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

echo "Web files copied!"

sudo sed -e "s/JENKINS_ARGS=\"/JENKINS_ARGS=\"--httpListenAddress=127.0.0.1 /" -i /etc/default/jenkins

sudo systemctl restart jenkins
sudo systemctl restart nginx
echo "Services configured and restarted!"