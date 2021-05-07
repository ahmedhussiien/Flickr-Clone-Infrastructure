#!/bin/sh

echo "### Installing prerequisite packages"
sudo apt update > /dev/null 2>&1
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

echo "### Adding Docker repository"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"

echo "### Installing Docker"
sudo apt update > /dev/null 2>&1
sudo apt install -y docker-ce
sudo systemctl enable docker

echo "### Installing docker compose"
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "### Adding user to docker group"
sudo usermod -aG docker ${USER}
sudo chmod 666 /var/run/docker.sock
sudo systemctl restart docker


