#!/bin/bash

# Args
# -h, --help: Display help
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: $0 [-v|--verbose] [-h|--help] [-c|--clean]"
  exit 0
fi
# -c, --clean: Clean up the stack
if [ "$1" == "-c" ] || [ "$1" == "--clean" ]; then
  clean=true
fi
# -v, --verbose: Enable verbose output
if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
  verbose=true
fi


output_message() {
  if [ "$verbose" == "true" ]; then
    echo "$1"
  fi
  
  if [ "$2" == "always" ]; then
    echo "$1"
  fi
}

# SYSTEM -----------------------------------------------------
SCRIPT_DIR=$(dirname "$(realpath "$0")")/..
output_message "Script directory: $SCRIPT_DIR"

source "$SCRIPT_DIR/.env"

# Stop stack if running
output_message "Checking if stack is running" "always"
if systemctl is-active --quiet pvt-dns.service; then
  systemctl stop pvt-dns.service
  output_message "Stack WAS running. (Stopped :) )" "always"
fi

# CERTS AND KEYS -----------------------------------------------------
CERT_DIR="$SCRIPT_DIR/certs"
# Check if nginx cert files exist. create if not
if [ ! -f "$SCRIPT_DIR/src/nginx/conf.d/nginx.crt" ] || [ ! -f "$SCRIPT_DIR/src/nginx/conf.d/nginx.key" ]; then
  output_message "Didn't find the nginx cert files. Time to make some more!"
  
  if [ ! -f "$CERT_DIR/nginx.crt" ] || [ ! -f "$CERT_DIR/nginx.key" ]; then
    output_message "Didn't find the certs directory. Creating it."
    mkdir -p "$CERT_DIR"
  fi
  
  # Create the cert and key
  output_message "Creating a 2048 bit RSA key and a self-signed cert.\\n Sit back and relax, the prime numbers are missing and it may take a while to find them." "always"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$CERT_DIR/nginx.key" -out "$CERT_DIR/nginx.crt" -subj "/CN=${NGINX_SERVER_NAME}"

  # Copy the cert and key to the nginx conf dir
  output_message "Copying the cert and key to the nginx conf directory"
  cp "$CERT_DIR/nginx.crt" "$SCRIPT_DIR/src/nginx/conf.d/nginx.crt"
  cp "$CERT_DIR/nginx.key" "$SCRIPT_DIR/src/nginx/conf.d/nginx.key"
fi

# UNBOUND CONFIGURATION -----------------------------------------------------
UNBOUND_DIR="$SCRIPT_DIR/src/unbound"
# Check if Unbound configuration exists. create if not
if [ ! -f "$UNBOUND_DIR/unbound.conf" ]; then
  mkdir -p "$UNBOUND_DIR"
  output_message "Loading default Unbound config" "always"

  # Create the Unbound configuration file
  cat <<EOT > "$UNBOUND_DIR/unbound.conf"
server:
    verbosity: 1
    num-threads: 2
    interface: 172.30.0.4
    access-control: 127.0.0.0/8 allow
    access-control: 172.30.0.0/24 allow
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
EOT

  # Download the root hints file
  output_message "Downloading the root hints file from: https://www.internic.net/domain/named.root" "always"
  curl -o "$UNBOUND_DIR/root.hints" https://www.internic.net/domain/named.root

  # Download the DNSSEC root trust anchor
  output_message "Downloading the DNSSEC root trust anchor from: https://data.iana.org/root-anchors/root-anchors.xml" "always"
  curl -o "$UNBOUND_DIR/root.key" https://data.iana.org/root-anchors/root-anchors.xml
fi

# SERVICE -----------------------------------------------------
SERVICE_FILE="/etc/systemd/system/pvt-dns.service"
output_message "Checking the service configuration" "always"
# Check if service file exists and create if not
if [ -f "$SERVICE_FILE" ]; then
  output_message "Found service file, checking if it needs to be updated"
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
    output_message "Service file was different. Recreating it."
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
    output_message "Service file updated and reloaded."
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
  output_message "Service file created and loaded."
fi

# Check if running and start if not
output_message "Starting the stack" "always"
if ! systemctl is-active --quiet pvt-dns.service; then
  systemctl start pvt-dns.service
fi