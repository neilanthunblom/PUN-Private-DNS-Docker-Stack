
Run pihole:
	1: Move "pihole" to the server
	2: cd into "pihole" and run "docker compose up -d"

Create service(for recovery on server reboot):
	1: move "pihole-newton.service" to the server under "/etc/systemd/"
	2: sudo systemctl start pihole-newton.service
	3: sudo systemctl enable pihole-newton.service
	4: sudo reboot
