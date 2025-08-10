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
    - pkg install -y qemu-guest-agent
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
I installed ansible on the same system that I'm running opentofu from. In order
for some of the modules to work, I needed to install ansible from pipx rather 
than apt. 

NOTES:
decided to go for directory setup since there should be overlap btwn noble and bsd
so wanted to be able to reuse roles and such

needed to install community.general for sysrc module
```
 $ ansible-galaxy collection install community.general
```

might need to change server ips on pf.conf since they're given dynamically
-> if can't ssh into nobles, check this first

for some reason pkg installation doesn't work on the first ansible run but
works on the second. annoying, but oh well

difference between shell and command sucks... shell works how I want it to

split site.yaml into two files because starting the firewall means that ansible
doesn't actually complete task because ssh session gets messed up. so run 
bastion.yaml first and then handle the two ubuntu vms

pyenv just isnt happening, that can be set up after ansible
very pleased with myself that dropping in a script, running it, removing the script
works to set up pyenv stuff

colorls isn't installing dependencies properly? manual install and then it works
except I didn't have to do that today for some reason... fixed?

cant find package asciinema, removing from list
ditto autojump
ditto bsdgames
ditto chafa
nvm -- need to do full upgrade to see them

needed to separate common pkg install from other common tasks so that it
could happen before some of the commands that noble servers need

needed to add 
'git config --global --add safe.directory /home/sawyeras/clones/bat-extras' 
for installing bat-extras to work?

for some reason bat-extras build was failing about git things
```
Verifying scripts...
batgrep:option_context skipped.
batgrep:output_with_color skipped.
batgrep:output_without_color skipped.
batgrep:output_without_separator skipped.
batgrep:regular_file skipped.
batgrep:respects_bat_style skipped.
batgrep:sanity_rg_works skipped.
batgrep:search_fixed skipped.
batgrep:search_from_stdin skipped.
batgrep:search_regex skipped.
batgrep:symlink_file skipped.
batpipe:batpipe_term_width failed.
lib_dsl:parse_simple_argsfatal: detected dubious ownership in repository at '/home/sawyeras/clones/bat-extras'
To add an exception for this directory, call:

        git config --global --add safe.directory /home/sawyeras/clones/bat-extras
One or more tests failed.
Run './test.sh --failed' for more detailed information.
```
even after running the command that they suggest. So I added the `--no-verify` flag
and it seems to be working just fine?

not created ethers.txt... cant tell what it was for, and it was being a pain
so I didn't feel like it

I tried to do something cool where I could have a docker-compose.yaml auto
generate based on what roles a host was given and a template, but it
kept not quite working and I don't have enough time to figure out
how to make it go. Would be cool for a larger project though

finally got ansible to set up stuff from hw3. Not the prettiest, but it's getting
the job done. 

# Services
Now that the VMs are created and running, it's time to set up some more
services. 

## Wireguard
guide: https://pimylifeup.com/wireguard-docker/

```
❯ docker run --rm -it ghcr.io/wg-easy/wg-easy wgpw 'super_secret_password'
Unable to find image 'ghcr.io/wg-easy/wg-easy:latest' locally
latest: Pulling from wg-easy/wg-easy
fe07684b16b8: Pull complete
65b9c193e6b7: Pull complete
826f8ad948ff: Pull complete
cb37e5b9a0a1: Pull complete
e3fd0cd8e9b9: Pull complete
93291203249b: Pull complete
4a55f9fa0217: Pull complete
4f4fb700ef54: Pull complete
fde2be46c20a: Pull complete
9d6d727c061f: Pull complete
Digest: sha256:5f26407fd2ede54df76d63304ef184576a6c1bb73f934a58a11abdd852fab549
Status: Downloaded newer image for ghcr.io/wg-easy/wg-easy:latest
PASSWORD_HASH='$2a$12$FTITipwicouxuElVfH1bGO8LWTXVlEOXbZzjfE/Mz4shyUewCIhVy'
```

connect at systemsec-04.cs.pdx.edu:51821
sign in with password
add client

able to access the web ui, but something obviously needs to change
with the config in order to use the vpn as would be wanted. 
moving on for now


## Wazuh
dont need to increase `max_map_count` because it's already above the required 262,144
```
❯ sysctl vm.max_map_count
vm.max_map_count = 1048576
```

clone docker images n such
```
$ git clone https://github.com/wazuh/wazuh-docker.git -b v4.12.0
```

changed pihole's https port to 8443 so that wazuh could have 443

## Semgrep
Chose this one because its fully open src and seemed like the setup was pretty
straighforward  

```
 $ pip install semgrep
 $ semgrep --config "p/default" # ran on current directory (?) will default rules
...


```
