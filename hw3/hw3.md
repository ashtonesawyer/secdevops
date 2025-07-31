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


