#!/bin/bash

verbose=false
clean=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--verbose) verbose=true ;;
        -c|--clean) clean=true ;;
        -h|--help) 
            echo "Usage: $0 [-v|--verbose] [-h|--help] [-c|--clean]"
            exit 0 
            ;;
        *) 
            echo "Unknown parameter passed: $1"
            exit 1 
            ;;
    esac
    shift
done

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

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "Environment file .env not found!"
    exit 1
fi
source "$SCRIPT_DIR/.env"

output_message "Checking if stack is currently running" "always"
if systemctl is-active --quiet PUNGuardDNS.service; then
    sudo systemctl stop PUNGuardDNS.service
    output_message "Stack WAS running. (Stopped :) )" "always"
fi

if [ "$clean" == "true" ]; then
    output_message "Cleaning up Docker containers and volumes" "always"
    docker-compose down -v
    sudo rm -rf "$CERT_DIR"
    sudo rm -rf "$PIHOLE_DIR/pihole" "$PIHOLE_DIR/dnsmasq.d" "$PIHOLE_DIR/logs"
    sudo rm -rf "$UNBOUND_DIR"
    sudo rm "$SERVICE_FILE"
    sudo systemctl daemon-reload
    exit 0
fi

# Pi-hole -----------------------------------------------------
PIHOLE_DIR="$SCRIPT_DIR/src/pihole"
output_message "Checking the Pi-hole persistence directory"

[ ! -d "$PIHOLE_DIR/persist/pihole" ] && mkdir -p "$PIHOLE_DIR/persist/pihole"
[ ! -d "$PIHOLE_DIR/persist/dnsmasq.d" ] && mkdir -p "$PIHOLE_DIR/persist/dnsmasq.d"
[ ! -d "$PIHOLE_DIR/persist/logs" ] && mkdir -p "$PIHOLE_DIR/persist/logs"
[ ! -d "$PIHOLE_DIR/persist/logs/lighttpd" ] && mkdir -p "$PIHOLE_DIR/persist/logs/lighttpd"

# NGINX CONFIGURATION -----------------------------------------------------
CERT_DIR="$SCRIPT_DIR/certs"
output_message "Checking the nginx configuration" "always"

if [ ! -f "$SCRIPT_DIR/src/nginx/conf.d/nginx.crt" ] || [ ! -f "$SCRIPT_DIR/src/nginx/conf.d/nginx.key" ]; then
    [ ! -d "$CERT_DIR" ] && mkdir -p "$CERT_DIR"
    
    output_message "Creating a 2048 bit RSA key and a self-signed cert." "always"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$CERT_DIR/nginx.key" -out "$CERT_DIR/nginx.crt" -subj "/CN=${NGINX_SERVER_NAME}" || { echo "Failed to generate certificates"; exit 1; }

    cp "$CERT_DIR/nginx.crt" "$SCRIPT_DIR/src/nginx/conf.d/nginx.crt"
    cp "$CERT_DIR/nginx.key" "$SCRIPT_DIR/src/nginx/conf.d/nginx.key"
    
    chmod 600 "$CERT_DIR/nginx.crt" "$CERT_DIR/nginx.key"
    rm "$CERT_DIR/nginx.crt" "$CERT_DIR/nginx.key"
fi

# UNBOUND CONFIGURATION -----------------------------------------------------
UNBOUND_DIR="$SCRIPT_DIR/src/unbound"
output_message "Checking the Unbound configuration" "always"

if [ ! -f "$UNBOUND_DIR/unbound.conf" ]; then
    mkdir -p "$UNBOUND_DIR"
    
    output_message "Loading default Unbound config" "always"
    
    cat <<EOT > "$UNBOUND_DIR/unbound.conf"
server:
    verbosity: 1
    num-threads: 2
    interface: 0.0.0.0
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

    curl -o "$UNBOUND_DIR/root.hints" https://www.internic.net/domain/named.root || { echo "Failed to download root hints"; exit 1; }
    curl -o "$UNBOUND_DIR/root.key" https://data.iana.org/root-anchors/root-anchors.xml || { echo "Failed to download root key"; exit 1; }
fi

# SERVICE -----------------------------------------------------
SERVICE_FILE="/etc/systemd/system/PUNGuardDNS.service"
output_message "Checking the service configuration" "always"

if [ -f "$SERVICE_FILE" ]; then
    output_message "Found service file, checking if it needs to be updated"

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
        sudo systemctl stop PUNGuardDNS.service
        sudo rm "$SERVICE_FILE"
        output_message "Service file was different. Recreating it."

        sudo tee "$SERVICE_FILE" > /dev/null <<EOT
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
        output_message "Reloading the daemon" "always"
        sudo systemctl daemon-reload
        sudo systemctl enable PUNGuardDNS.service
        output_message "Service file updated and reloaded."
    fi
else
    sudo tee "$SERVICE_FILE" > /dev/null <<EOT
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
    output_message "Reloading the daemon" "always"
    sudo systemctl daemon-reload
    sudo systemctl enable PUNGuardDNS.service
    output_message "Service file created and loaded."
fi

output_message "Starting the stack" "always"
if ! systemctl is-active --quiet PUNGuardDNS.service; then
    sudo systemctl start PUNGuardDNS.service
fi