# Docker Compose
add self to docker group w/ `sudo usermod -aG docker $USER`  
log out and back in to take effect

## Pi-Hole
Got most of the setting from https://github.com/pi-hole/docker-pi-hole and 
changed them to what seemed mostly reasonable? Guessing here...

```
pihole error from daemon failed bind to port 0.0.0.0:53 address already in use

 $ sudo systemctl disable systemd-resolved.service
 $ sudo systemctl stop systemd-resolved
```

uggghhhhhh  
add 1.1.1.1 to docker compose to make life not suck

## Samba
found an image on docker hub that seems legit  
used suggested config

need to change firewall rules on bsd
also need to change nftables rules... euugghghghghgh


