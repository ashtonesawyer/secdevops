# Pre-template ProxMox Setup
Before I could make the templates, some set up had to be done on Proxmox

## Remove Liscence Warnings

```bash
 $ sudo bash

# remove warning for Proxmox < 8.4.2
 $ curl -LO https://free-pmx.pages.dev/tools/free-pmx-no-subscription_0.2.0.deb
 $ dpkg -i free-pmx-no-subscription_0.2.0.deb

# update Proxmox
 $ apt update && apt upgrade -y

# remove warning for Proxmox >= 8.4.2
 $ curl -LO https://free-pmx.pages.dev/tools/free-pmx-no-subscription_0.3.0~pre1.deb
 $ dpkg -i free-pmx-no-subscription_0.3.0~pre1.deb
```

## Set up SNAT

```
 $ apt install dnsmasq
 $ systemctl disable --now dnsmasq
```

In the UI:
- Naviage to Datacenter > SDN > Zones
    - Create a new Simple zone with and ID of `snat`
        - Tick `automatic DHCP`
- Navigate to Datacenter > SDN > VNET
    - Create a new VNET with ID of `vnet0`
    - Create a new subnet from `vnet0`
        - Set the subnet to a private IP range
        - Set he gateway to the base address of the subnet
        - Tick the`snat` option
        - Go to DHCP Ranges tab and create a new range that is within the subnet
- Click Apply on the SDN panel

## Set up NAT forwarding
This is so that we can ssh to our FreeBSD host through the Proxmox server. 

In `/etc/nftables.conf`

```
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority filter;
	}
	chain forward {
		type filter hook forward priority filter;
	}
	chain output {
		type filter hook output priority filter;
	}
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100; policy accept;
        ip daddr <HOST_IP> tcp dport 22 dnat to 172.18.100.100:22
    }
}
```

Replace `<HOST_IP>` with the IP address given by:

```
 $ ip -o -f inet addr show vmbr0 | awk '{print $4}' | cut -f1 -d/
```

Then apply the new rules:

```bash
 $ nft -f /etc/nftables.conf
 $ nft list table ip nat
```

## Move SSH Port
Finally, since we are redirecting our ssh traffic on port 22 to the FreeBSD
host, we need to move the ssh port on the Proxmox server to 8022 so that it
can still be accessed. 

```
 $ sed -i 's/#Port 22/Port 8022/' /etc/ssh/sshd_config
```

# Setting up templates
I set up two templates: one for FreeBSD and one for Ubuntu. Both were set up 
primarily from the command line, though some tweaks were done using the UI. 

## Cloud Images
```
 $ sudo bash
 $ cd /var/lib/vz/images
 $ curl -LO https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.imh
 $ curl -LO FreeBSD-14.3-STABLE-amd64-BASIC-CLOUDINIT-20250724-f0a7a1bda375-272016-ufs.qcow2.xz
 $ unxz FreeBSD-14.3-STABLE-amd64-BASIC-CLOUDINIT-20250724-f0a7a1bda375-272016-ufs.qcow2.xz
```

## Setting up the Ubuntu template

