#!/bin/sh

echo "### Installing Java"
sudo apt update > /dev/null 2>&1
sudo apt install -y openjdk-8-jdk

echo "### Adding Jenkins repository"
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

echo "### Installing Jenkins"
sudo apt update > /dev/null 2>&1
sudo apt install -y jenkins

echo "### Adding Jenkins to docker group"
sudo usermod -aG docker jenkins
sudo service jenkins restart

echo "### Jenkins activation password"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword


