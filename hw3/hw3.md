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

actually ingore that...  
follow the guide that logan sent in the discord  
then change /etc/netplan/clou.... to be
```
network:
  version: 2
  ethernets:
    eth0:
      match:
        macaddress: "bc:24:11:25:01:f5"
      dhcp4: true
      set-name: "eth0"
      nameservers:
        addresses: [192.168.33.67]
```

then try with `sudo netplan try` and keep with `sudo netplan apply`  
can double check that it's using the right IP with `dig`

## Samba
found an image on docker hub that seems legit  
used suggested config

need to change firewall rules on bsd
also need to change nftables rules... euugghghghghgh


