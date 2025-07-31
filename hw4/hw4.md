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

```
$  qemu-img resize ubuntu-24.04-server-cloudimg-amd64.img 32G
$  qm create 1000 --name "template-ubuntu" --ostype l26 --memory 4096 --agent 1 --bios seabios --machine q35 --cpu host --socket 1 --cores 4 --vga serial0 --serial0 socket --net0 virtio,bridge=vnet0
$  qm importdisk 1000 ubuntu-24.04-server-cloudimg-amd64.img local-lvm
$  qm set 1000 --scsihw virtio-scsi-pci --virtio0 local-lvm:vm-1000-disk-0,discard=on
$  qm set 1000 --boot order=virtio0
$  qm set 1000 --ide2 local-lvm:cloudinit
$  cat << EOF | tee /var/lib/vz/snippets/vendor.yaml
#cloud-config
runcmd:
   - apt update
   - apt install -y qemu-guest-agent
   - systemctl start qemu-guest-agent
   - reboot
EOF
 $  qm set 1000 --cicustom "vendor=local:snippets/vendor.yaml"
 $  qm set 1000 --ciuser student
 $  qm set 1000 --cipassword $(openssl passwd -6 super_secret_password)
 $  qm set 1000 --ipconfig0 ip=dhcp
 $  qm cloudinit update 1000
 $  qm template 1000
```

At the end of these commands, we have a template ubuntu server with default
creds `student:super_secret_password` that can be cloned. 

## Setting up the FreeBSD template
The process is much the same as above. There are a couple changes:
- use the FreeBSD image in `resize` and `importdisk`
- change the name to `template-freebsd` in `create`
- The ID will be 1001 instead of 1000
- Skip creating `/var/lib/vz/snippets/vendor.yaml`

After creating the template as above, I also added another NIC using the web 
UI. Go to template-freebsd > Hardware > Add > Network Device and add a E1000
on the internal network. I also changed net0 from virtio to e1000. 

# Terraform (OpenTofu)
I split my terraform script up into two files: one for the provider and one for
the actual machines. 

## providers.tf
```tf
terraform {
        required_version = ">= 0.15"
        required_providers {
                proxmox = {
                        source = "telmate/proxmox"
                        version = "3.0.2-rc03"
                }
        }
}

provider "proxmox" {
        pm_debug = true
        pm_tls_insecure = true

        pm_api_url = "https://systemsec-04.cs.pdx.edu:8006/api2/json"
}
```

## main.tf
```
```

## Running 
```
 $ tofu init
Initializing the backend...

Initializing provider plugins...
- Finding telmate/proxmox versions matching "3.0.2-rc03"...
- Installing telmate/proxmox v3.0.2-rc03...
- Installed telmate/proxmox v3.0.2-rc03. Signature validation was skipped due to the registry not containing GPG keys for this provider

OpenTofu has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that OpenTofu can guarantee to make the same selections by default when
you run "tofu init" in the future.

OpenTofu has been successfully initialized!

You may now begin working with OpenTofu. Try running "tofu plan" to see
any changes that are required for your infrastructure. All OpenTofu commands
should now work.

 $ export PM_USER=student@pve
 $ export PM_PASS=<password>

 $ tofu plan
```


NOTE:  
rm eth0 renaming from rc.conf after cloud init
