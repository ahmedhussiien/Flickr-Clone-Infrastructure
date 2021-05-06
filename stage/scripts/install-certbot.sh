#!/bin/sh

echo "### Adding certbot repository"
sudo add-apt-repository -y ppa:certbot/certbot > /dev/null 2>&1
sudo apt-get update > /dev/null 2>&1

echo "### Installing certbot"
sudo apt-get install -y certbot