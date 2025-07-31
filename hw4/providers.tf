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
	pm_api_url = "https://systemsec-04.cs.pdx.edu:8006/api2/json"

	pm_debug = true
	pm_tls_insecure = true
}
