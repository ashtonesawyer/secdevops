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
   cipassword = "PASSWD_HASH"

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

resource "proxmox_vm_qemu" "server0" {
	name		= "noble0"
	description	= "Ubuntu VM"
	target_node	= "systemsec-04"
	clone		= "template-ubuntu"
	vmid		= 101
	agent		= 1

	memory		= 4096
	scsihw		= "virtio-scsi-pci"

	os_type		= "cloud-init"
	ipconfig0	= "ip=dhcp"
	ciupgrade	= true
	cicustom	= "vendor=local:snippets/vendor.yaml"
	ciuser		= "sawyeras"
   cipassword = "PASSWD_HASH"

	cpu {
		cores = 4
	}
	
	network {
		id = 0
		model = "virtio"
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

resource "proxmox_vm_qemu" "server1" {
	name		= "noble1"
	description	= "Ubuntu VM"
	target_node	= "systemsec-04"
	clone		= "template-ubuntu"
	vmid		= 102
	agent		= 1

	memory		= 4096
	scsihw		= "virtio-scsi-pci"

	os_type		= "cloud-init"
	ipconfig0	= "ip=dhcp"
	ciupgrade	= true
	cicustom	= "vendor=local:snippets/vendor.yaml"
	ciuser		= "sawyeras"
   cipassword = "PASSWD_HASH"

	cpu {
		cores = 4
	}

	network {
		id = 0
		model = "virtio"
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
	
