DB_ADMIN_USERNAME=$1
DB_ADMIN_PASSWORD=$2

# Import the public key
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -

# Create a list file for MongoDB.
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# Install the MongoDB packages.
sudo apt-get update
sudo apt-get install -y mongodb-org

# Start mongo
sudo systemctl start mongod

# Start mongo following a system reboot
sudo systemctl enable mongod

# Simple wait for mongod to be ready
sleep 5

# Add admin user
mongo <<EOF
    use admin

    db.createUser({
    user: "$DB_ADMIN_USERNAME",
    pwd: "$DB_ADMIN_PASSWORD",
    roles: [
        { role: "userAdminAnyDatabase", db: "admin" },
        "readWriteAnyDatabase",
    ],
    });
EOF

# Enable authentication
sudo sed -e 's/#security:/security:\n  authorization: "enabled"/' -i /etc/mongod.conf 

# Enable remote connections
sudo sed -e 's/bindIp:.*/bindIp: 0.0.0.0/' -i  /etc/mongod.conf 

# Restart mongo
sudo systemctl restart mongod

# Open port 27017
sudo ufw allow 27017
sudo ufw allow ssh
sudo ufw --force enable