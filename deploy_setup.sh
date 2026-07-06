#!/usr/bin/env bash

# LocalMate Production VM Deployment Setup Script
# Works on Ubuntu 22.04 / 24.04 LTS
# Installs PostgreSQL, Redis, Nginx, Python virtual environment, and configures services.

set -e

# Configuration
DOMAIN="kcmkcmkcmkcmkcmkcmkcm.dpdns.org"
DB_NAME="localmate"
DB_USER="localmate"
DB_PASSWORD="localmate_prod_pass_123"  # Change this to a secure password in production!
PROJECT_DIR="/var/www/localmate"
UPLOAD_DIR="/var/lib/localmate/uploads"

echo "=========================================================="
echo "    Starting LocalMate Deployment Setup on Ubuntu VM"
echo "=========================================================="

# 1. Update and install packages
echo "Updating packages..."
sudo apt update && sudo apt upgrade -y

echo "Installing system dependencies..."
sudo apt install -y python3-pip python3-venv postgresql postgresql-contrib redis-server nginx certbot python3-certbot-nginx git

# 2. Setup PostgreSQL
echo "Configuring PostgreSQL database and user..."
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"

sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# 3. Directory Setup
echo "Creating application and media storage folders..."
sudo mkdir -p $PROJECT_DIR
sudo mkdir -p $UPLOAD_DIR
sudo chown -R ubuntu:ubuntu $PROJECT_DIR
sudo chown -R ubuntu:ubuntu $UPLOAD_DIR

# 4. Copy current code (assumes this script runs from repo root or repo cloned to target dir)
if [ -d "./backend" ]; then
    echo "Copying backend code..."
    cp -r ./backend $PROJECT_DIR/
fi

# 5. Virtual Environment & Requirements
echo "Creating virtual environment and installing python dependencies..."
python3 -m venv $PROJECT_DIR/backend/venv
source $PROJECT_DIR/backend/venv/bin/activate
pip install --upgrade pip
pip install -r $PROJECT_DIR/backend/requirements.txt

# 6. Seed initial database data
echo "Seeding the database..."
export POSTGRES_USER="$DB_USER"
export POSTGRES_PASSWORD="$DB_PASSWORD"
export POSTGRES_SERVER="localhost"
export POSTGRES_PORT="5432"
export POSTGRES_DB="$DB_NAME"
export UPLOAD_DIR="$UPLOAD_DIR"
python3 $PROJECT_DIR/backend/seed_data.py

# 7. Systemd Service Setup
echo "Configuring Systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/localmate.service
[Unit]
Description=LocalMate FastAPI Backend
After=network.target postgresql.service redis-server.service

[Service]
User=ubuntu
WorkingDirectory=$PROJECT_DIR/backend
Environment=POSTGRES_USER=$DB_USER
Environment=POSTGRES_PASSWORD=$DB_PASSWORD
Environment=POSTGRES_SERVER=localhost
Environment=POSTGRES_PORT=5432
Environment=POSTGRES_DB=$DB_NAME
Environment=UPLOAD_DIR=$UPLOAD_DIR
Environment=SECRET_KEY=localmate_production_secret_key_change_me
ExecStart=$PROJECT_DIR/backend/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable redis-server postgresql localmate
sudo systemctl restart redis-server postgresql localmate

# 8. Configure Nginx Reverse Proxy
echo "Configuring Nginx reverse proxy..."
cat <<EOF | sudo tee /etc/nginx/sites-available/localmate
server {
    listen 80;
    server_name $DOMAIN;

    # Serve uploaded media directly via Nginx
    location /uploads/ {
        alias $UPLOAD_DIR/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Proxy API requests to FastAPI
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site configuration
if [ ! -f "/etc/nginx/sites-enabled/localmate" ]; then
    sudo ln -s /etc/nginx/sites-available/localmate /etc/nginx/sites-enabled/
fi

# Remove default site if present
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi

sudo nginx -t
sudo systemctl restart nginx

echo "=========================================================="
echo "    Setup Completed Successfully!"
echo "=========================================================="
echo "Next Steps:"
echo "1. Run Certbot to acquire SSL certificate for your domain:"
echo "   sudo certbot --nginx -d $DOMAIN"
echo "2. Build the Flutter APK using target domain: $DOMAIN"
echo "=========================================================="
