#!/bin/bash

# SYSTEM -----------------------------------------------------
SCRIPT_DIR=$(dirname "$(realpath "$0")")/..

source "$SCRIPT_DIR/.env"

# Stop stack if running
if systemctl is-active --quiet pvt-dns.service; then
  systemctl stop pvt-dns.service
fi

# CERTS AND KEYS -----------------------------------------------------
CERT_DIR="$SCRIPT_DIR/certs"
# Check if nginx cert files exist. create if not
if [ ! -f "$SCRIPT_DIR/src/nginx/conf.d/nginx.crt" ] || [ ! -f "$SCRIPT_DIR/src/nginx/conf.d/nginx.key" ]; then
    
  # Check if certs dir exists. create if not
  if [ ! -f "$CERT_DIR/nginx.crt" ] || [ ! -f "$CERT_DIR/nginx.key" ]; then
    mkdir -p "$CERT_DIR"
  fi
  
  # Create the cert and key
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$CERT_DIR/nginx.key" -out "$CERT_DIR/nginx.crt" -subj "/CN=${NGINX_SERVER_NAME}"

  # Copy the cert and key to the nginx conf dir
  cp "$CERT_DIR/nginx.crt" "$SCRIPT_DIR/src/nginx/conf.d/nginx.crt"
  cp "$CERT_DIR/nginx.key" "$SCRIPT_DIR/src/nginx/conf.d/nginx.key"
fi

# SERVICE -----------------------------------------------------
SERVICE_FILE="/etc/systemd/system/pvt-dns.service"

# Check if service file exists and create if not
if [ -f "$SERVICE_FILE" ]; then
  # Check if service file is the same. recreate if not
  if ! diff -q "$SERVICE_FILE" <(cat <<EOT
[Unit]
Description=Start the secure and private DNS stack
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker-compose -f $SCRIPT_DIR/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f $SCRIPT_DIR/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOT
); then
    systemctl stop pvt-dns.service
    rm "$SERVICE_FILE"
    # Recreate the service file
    cat <<EOT > "$SERVICE_FILE"
[Unit]
Description=Start the secure and private DNS stack
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker-compose -f $SCRIPT_DIR/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f $SCRIPT_DIR/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOT
    systemctl daemon-reload
    systemctl enable pvt-dns.service
  fi
else
  # Create the service file if it doesn't exist
  cat <<EOT > "$SERVICE_FILE"
[Unit]
Description=Start the secure and private DNS stack
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker-compose -f $SCRIPT_DIR/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f $SCRIPT_DIR/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOT

  systemctl daemon-reload
  systemctl enable pvt-dns.service
fi

# Check if running and start if not
if ! systemctl is-active --quiet pvt-dns.service; then
  systemctl start pvt-dns.service
fi