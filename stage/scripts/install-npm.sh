#!/bin/sh

echo "### Installing node"
sudo apt update > /dev/null 2>&1
sudo apt install -y nodejs

echo "### Installing npm"
sudo apt install npm
