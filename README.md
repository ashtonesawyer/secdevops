# System Administration + Devops
This is a backup of my homework from System Administration and Devops (CS510 - Summer 25) that was originally hosted on GitLab. The main markdown file in each folder is the walkthrough of what I did for the homework.

Below is a breif description of the different homeworks.

## HW1 - VM Setup
I set up one FreeBSD VM and one Ubuntu VM in VirtualBox with the FreeBSD machine configured as the firewalled router for the Ubuntu machine

## HW2 - Networking + Suricata
I changed the network for the VMs so that the FreeBSD machine's port 22 redirected to the Ubuntu machine's port 22. I also installed and configured Suricata on FreeBSD.

## HW3 - Docker Services
I set up Pihole and Samba as containerized services on the Ubuntu machine.

## HW4 - IaC, Configuration Management, and More Services
I moved off of VirtualBox to ProxMox. I used Terraform (OpenTofu) to create the VMs and Ansible to configure them. I added containerized Wireguard and Wazuh and installed Semgrep on the Ubuntu VMs.

## Final - Even More Services
I added containerized GitLab, BitWarden, and Frigate. I also set up a CI/CD pipeline with Jekyll for a repo on the gitlab. 
