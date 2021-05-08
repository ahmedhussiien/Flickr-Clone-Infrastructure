REDIS_PASSWORD=$1

# Install redis
sudo apt update
sudo apt install -y redis-server

# Edit config file
sudo sed -e "s/supervised no/supervised systemd/" -i /etc/redis/redis.conf
sudo sed -e "s/bind 127.0.0.1/bind 0.0.0.0/" -i /etc/redis/redis.conf
sudo sed -e "s/# requirepass .*/requirepass $REDIS_PASSWORD/" -i /etc/redis/redis.conf

# Restart redis
sudo systemctl restart redis.service

# Open port 6379
sudo ufw allow 6379
sudo ufw allow ssh
sudo ufw --force enable
