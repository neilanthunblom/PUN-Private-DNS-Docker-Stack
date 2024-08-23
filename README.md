# PUN (Pihole, Unbound, Nginx) - Privacy enhanced Pi-hole with Unbound and Nginx

## Overview

This is a simple project to create a local dns server using a Raspberry Pi. It uses Pi-hole for ad blocking and local DNS along with Unbound for DoT and a secure recursive resolver. This is all wrapped up in an Nginx reverse proxy to provide a secure web interface for Pi-hole inspection and configuration.

TL;DR: This is a privacy enhanced Pi-hole setup with DoT and a reverse proxy for secure access to the web interface. All wrapped up in docker compose with a bash script to configure and manage the stack.

## Project Goals

The goal was to enhance my already existing rendundant docker Pi-hole setup with and easier to manage deployment/maintance config along with using DoT and to avoid using my ISP's DNS servers. For extra (unnecessary) security, I also wanted to use a reverse proxy to access the Pi-hole web interface using ssl and allow access to both Pi-hole and Unbound using a single port.

This this stack is designed to be a semi-automated deployment of the same configuration across multiple servers, allowing for easy redundancy and failover. My goal was to be able to create a new Pi-hole server by only changing the environment vars and then running a script to manage certs and create/manage a daemon for the whole stack to ensure recovery after a reboot. This is made possible by using a bash script to build and configure the stack and an `.env` file to store the configuration.

## Features

- [Pi-hole](https://pi-hole.net/) For ad blocking and local DNS via the image [pihole/pihole](https://hub.docker.com/r/pihole/pihole)

- [Unbound](https://nlnetlabs.nl/projects/unbound/about/) For DoT and a secure recursive resolver [mvance/unbound](https://hub.docker.com/r/mvance/unbound)

- [Nginx](https://www.nginx.com/) For a reverse proxy to Pi-hole and Unbound [nginx](https://hub.docker.com/_/nginx)

- [Docker](https://www.docker.com/) For packing it all together in a portable and reproducible way

## Deployment

### Requirements
* Raspberry Pi (tested on Pi 4 and CM4)
* Raspbian OS (tested on Buster)
* Docker/Docker-compose

### Steps
