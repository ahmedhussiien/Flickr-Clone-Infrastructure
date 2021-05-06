#!/bin/sh

DOMAIN=$1
EMAIL=$2

sudo certbot certonly --standalone --non-interactive --agree-tos --preferred-challenges http -d $DOMAIN -d www.$DOMAIN -m $EMAIL