# PUN (Pihole, Unbound, Nginx) - Privacy enhanced Pi-hole with Unbound and Nginx

## Overview

This is a simple project to create a local, privacy and security focused, DNS resolver/sinkhole using a Raspberry Pi. It uses Pi-hole for ad blocking, local DNS for assigning resolvable urls to LAN clients, along with Unbound for DoT and a secure recursive resolver to mitigate ISP data mining. This is all run behind an Nginx reverse proxy to provide a secure and maintanable web interface for Pi-hole inspection and configuration.

**TL;DR: This is a privacy enhanced Pi-hole setup with DoT and a reverse proxy for secure access to the web interface. All wrapped up in docker compose with a bash script to configure and manage the stack.**

## Project Goals

The goal was to enhance my already existing rendundant docker Pi-hole setup with and easier to manage deployment/maintance config along with using DoT and to avoid using my ISP's DNS servers. For extra (unnecessary) security, I also wanted to use a reverse proxy to access the Pi-hole web interface using ssl and allow access to both Pi-hole and Unbound using a single port.

This this stack is designed to be a semi-automated deployment of the same configuration across multiple servers, allowing for easy redundancy and failover. My goal was to be able to create a new Pi-hole server by only changing the environment vars and then running a script to manage certs and create/manage a daemon for the whole stack to ensure recovery after a reboot. This is made possible by using a bash script to build and configure the stack and an `.env` file to store the configuration.

## Features

### This stack is comprised of the following

- [Pi-hole](https://pi-hole.net/) For ad blocking and local DNS via the image [pihole/pihole](https://hub.docker.com/r/pihole/pihole)
- [Unbound](https://nlnetlabs.nl/projects/unbound/about/) For DoT and a secure recursive resolver [mvance/unbound](https://hub.docker.com/r/mvance/unbound)
- [Nginx](https://www.nginx.com/) For a reverse proxy to Pi-hole and Unbound [nginx](https://hub.docker.com/_/nginx)
- [Docker](https://www.docker.com/) For packing it all together in a portable and reproducible way

## Requirements

- Raspberry Pi or similar ARM device
- Docker/Docker-compose

### Tested Hardware

- [Raspberry Pi Compute Module 4](https://www.raspberrypi.org/products/compute-module-4/)
- [Raspberry Pi Compute Module 4 IO Board](https://www.raspberrypi.org/products/compute-module-4-io-board/)
- [Raspberry Pi 4 Model B](https://www.raspberrypi.org/products/raspberry-pi-4-model-b/)

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/neilanthunblom/PUN-Private-DNS-Docker-Stack
cd PUN-Private-DNS-Docker-Stack
```

### 2. Copy the `sample.env` to `.env` and edit the configuration

```bash
cp sample.env .env
vim .env
```

### 3. Run the setup script

```bash
chmod +x ./bin/setup.sh
./bin/setup.sh
```