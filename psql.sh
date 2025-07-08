#!/bin/bash

# Update the system packages
echo "Updating system packages..."
sudo dnf update -y

# Install PostgreSQL 16 server and client packages
echo "Installing PostgreSQL 16..."
sudo dnf install postgresql16 postgresql16-server -y

# Initialize the PostgreSQL database
echo "Initializing PostgreSQL database..."
sudo postgresql-setup --initdb

# Start and enable the PostgreSQL service
echo "Starting and enabling PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Set a password for the 'postgres' user (replace 'your-password' with a strong password)
echo "Setting password for 'postgres' user..."
sudo -i -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'mypass';" # Replace 'your-password' with a strong password

# Check the status of the PostgreSQL service
echo "Checking PostgreSQL service status..."
sudo systemctl status postgresql

# Find the location of the pg_hba.conf and postgresql.conf files
PG_HBA_FILE=$(sudo -u postgres psql -t -P format=unaligned -c "SHOW hba_file;")
POSTGRESQL_CONF_FILE=$(sudo -u postgres psql -t -P format=unaligned -c "SHOW config_file;")

# Backup the original files
sudo cp "$PG_HBA_FILE" "$PG_HBA_FILE.bak"
sudo cp "$POSTGRESQL_CONF_FILE" "$POSTGRESQL_CONF_FILE.bak"

# Modify pg_hba.conf to allow MD5 authentication for local and IPv4 connections
# (Assuming your desired pg_hba.conf is already configured with md5)
# Note: This example replaces specific lines for demonstration purposes.
# Adjust the sed commands to match your existing pg_hba.conf content.
sudo sed -i "s/^local\s\+all\s\+all\s\+peer/local   all             all                                     md5/" "$PG_HBA_FILE"
sudo sed -i "s/^host\s\+all\s\+all\s\+127\.0\.0\.1\/32\s\+ident/host    all             all             127.0.0.1\/32            md5/" "$PG_HBA_FILE"
sudo sed -i "s/^host\s\+all\s\+all\s\+0\.0\.0\.0\/0\s\+ident/host    all             all             0.0.0.0\/0               md5/" "$PG_HBA_FILE"


# Modify postgresql.conf to listen on all addresses
sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" "$POSTGRESQL_CONF_FILE"

# Reload the PostgreSQL configuration
echo "Reloading PostgreSQL configuration..."
sudo systemctl reload postgresql # Or restart if you changed listen_addresses

# Create a new user and database (replace 'yourusername' and 'database_name' with your desired values)
echo "Creating a new database user and database (Optional)..."
sudo -i -u postgres psql <<EOF
CREATE USER backend WITH PASSWORD 'securepass';
CREATE DATABASE backend_db;
GRANT ALL PRIVILEGES ON DATABASE backend_db TO backend;
\l
\q
EOF



echo "PostgreSQL configuration updated for MD5 authentication."