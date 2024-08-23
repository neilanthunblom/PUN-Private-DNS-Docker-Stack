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

# UNBOUND CONFIGURATION -----------------------------------------------------
UNBOUND_DIR="$SCRIPT_DIR/src/unbound"
# Check if Unbound configuration exists. create if not
if [ ! -f "$UNBOUND_DIR/unbound.conf" ]; then
  mkdir -p "$UNBOUND_DIR"

  # Create the Unbound configuration file
  cat <<EOT > "$UNBOUND_DIR/unbound.conf"
server:
    verbosity: 1
    num-threads: 2
    interface: 0.0.0.0
    access-control: 0.0.0.0/0 refuse
    access-control: 127.0.0.0/8 allow
    access-control: ::1 allow
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    ssl-upstream: yes
    auto-trust-anchor-file: "/opt/unbound/etc/unbound/root.key"
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    prefetch: yes
    rrset-cache-size: 100m
    msg-cache-size: 50m
    root-hints: "/opt/unbound/etc/unbound/root.hints"
    include: "/opt/unbound/etc/unbound/unbound.conf.d/pi-hole.conf"
EOT

  # Download the root hints file
  curl -o "$UNBOUND_DIR/root.hints" https://www.internic.net/domain/named.root

  # Download the DNSSEC root trust anchor
  curl -o "$UNBOUND_DIR/root.key" https://data.iana.org/root-anchors/root-anchors.xml
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