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
- Create a new `freebsd.yaml` to replace `vendor.yaml

After creating the template as above, I also added another NIC using the web 
UI. Go to template-freebsd > Hardware > Add > Network Device and add a E1000
on the internal network. I also changed net0 from virtio to e1000. 

```
 $ cat freebsd.yaml
#cloud-config
runcmd:
    - pkg update
    - pkg install -y qemu_guest_agent
    - sysrc qemu_guest_agent_enable="YES"
    - reboot
```

# Terraform (OpenTofu)
I split my terraform script up into two files: one for the provider and one for
the actual machines. 

## providers.tf
I basically just copied this during class and haven't touched it since. It
seems to work like a charm, so good enough. 

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
Setting up the terraform script for each VM was a little frustrating.
When cloning a template from the Proxmox UI all of the settings for the VM
(cloudinit users, NICs, drives, etc.) are carried over. The tf `clone` keyword
only clones the disk data, so all of the setup done on the template needs to be
done explicitly within the script. 

Fortunately, we can use the commands from setting up the templates as a guide
for writing the terraform script, and most all of the keywords are the same. 

This is the terraform for the FreeBSD bastion. The Ubuntu VMs are very similar.

It is worth noting that the keyword where it says `bastion` below must be
unique to each VM that gets created.

```tf
resource "proxmox_vm_qemu" "bastion" {
	name	 	= "bsd"
	description	= "FreeBSD Bastion"
	target_node 	= "systemsec-04"
	clone 		= "template-freebsd"
	vmid		= 100
	agent		= 1

	memory 		= 4096
	scsihw		= "virtio-scsi-pci"

	os_type		= "cloud-init"
	ipconfig0	= "ip=dhcp"
	ciupgrade	= true
	cicustom	= "vendor=local:snippets/freebsd.yaml"
	ciuser		= "sawyeras"
	cipassword	= "SHA512-passwd-hash"

	cpu {
		cores = 4
	}
	
	network {
		id = 0
		model = "e1000"
		bridge = "vnet"
	}

	network {
		id = 1
		model = "e1000"
		bridge = "internal"
	}

	disk {
		slot = "ide2"
		type = "cloudinit"
		storage = "local-lvm"
	}

	disk {
		slot = "virtio0"
		storage = "local-lvm"
		size = "32G"
	}
	
	serial {
		id = 0
		type = "socket"
	}
	
}
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

FreeBSD is not great at running cloud init. In order to get it to run, you have
to log on to the machine, install cloud-init, and add it to `rc.conf`. Then
restart and cloud init will actually run as expected. 

```
 $ pkg install py311-cloud-init
 $ sysrc cloudinit_enable="YES"
 $ reboot
```
It's also worth noting that the cloud init process changes the name of `em0` to
`eth0`. This can be fixed by removing the line in `rc.conf` that renames the 
interface. 

The Ubuntu VMs run cloud init just fine after being created. 

# Ansible

# Services
Now that the VMs are created and running, it's time to set up some more
services. 

## Wireguard
take config from img github repo  
stuff didn't auto populate correctly, it seems  
but I don't want to figure out how to fix it right this second

## Wazuh
This is confusing... what am I supposed to be doing? 

## 
