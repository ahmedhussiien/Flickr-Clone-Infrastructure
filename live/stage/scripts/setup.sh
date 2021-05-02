#!/bin/sh

## Install Nginx
apt-get -y update > /dev/null 2>&1
apt install -y nginx > /dev/null 2>&1
echo "Nginx installed!"

## Touch web files
cat << EOM > /var/www/html/index.html
<html>
	<head>
		<title>Flickr staging!</title>
	</head>
	<body">
		<div> Flickr staging is up & running!</div>
		<img src="https://raw.githubusercontent.com/ahmedhussiien/ahmedhussiien/master/coding_cat.gif"></img>
	</body>
</html>
EOM
echo "Web files copied!"

## Install certbot
apt install -y python-certbot-nginx > /dev/null 2>&1
ufw allow https > /dev/null 2>&1
echo "Certbot installed!"

## Get SSL certificate
SITE_TLD=$1
CERTBOT_EMAIL=$2
certbot --nginx --noninteractive --agree-tos --cert-name ${SITE_TLD} -d www.${SITE_TLD} -m ${CERTBOT_EMAIL}

echo "Setup is done!"