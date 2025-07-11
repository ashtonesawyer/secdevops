# SSH 
The goal is for it to look like the FreeBSD host is running all provided 
services. A part of doing this is to redirect traffic from bsd to the 
host that is actually providing that service. 

## Setting up ssh-alt
Part of redirecting ssh traffic from bsd to noble means that if I want to keep
ssh-ing to bsd I need another port that doesn't get redirected. 

The first set in doing so was to create another port forward from my local 
machine to the VirtualBox VM. 

![port forward](./img/port_forward)

Then, I adjusted the firewall rule to allow traffic on port 8022. 

```conf
pass in on $ext_if proto tcp to port { ssh, 8022 } keep state (max-src-conn 15, max-src-conn-rate 3/1, overload <bruteforce> flush global)
```

And instantiated it

```zsh
 > pfctl -vf /etc/pf.conf
```

Finally, I changed `/etc/ssh/sshd_config` so that the ssh service would run on
port 8022 instead of 22

```
...
# Note that some of FreeBSD's defaults differ from OpenBSD's, and
# FreeBSD has a few additional options.

Port 8022
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::
...
```

## Redirecting SSH Traffic
There are two rules that need to be added to `pf.conf` to redirect the ssh
traffic

```conf
# redirect traffic from bsd to noble
rdr pass log on $ext_if inet proto tcp from any to port ssh -> $server port ssh

# allow redirected traffic to pass through firewall
pass out on $int_if proto tcp from any to $server port { ssh } keep state
```
At this point I should have been able to ssh into noble through bsd without a 
ProxyJump, but it wasn't working. `tcpdump` showed that the ssh packets were 
reaching em0 and being logged by the redirect rule, but weren't reaching
em1 or noble. 

The problem ended up being that `$server` had the wrong IP address. It said 
192.168.33.63 instead of 192.163.33.69. Once that was changed, it worked as
expected. 

The last thing was to update the `.ssh/config` on my local machine. 

```
Host bsd
	Hostname localhost
	Port 8022
	User sawyeras

Host noble
	Hostname localhost
	Port 2222
	User sawyeras
```

# Suricata

## Install + Basic Config
```
 > sudo pkg install suricata

...

Message from suricata-7.0.10:

--
If you want to run Suricata in IDS mode, add to /etc/rc.conf:

        suricata_enable="YES"
        suricata_interface="<if>"

NOTE: Declaring suricata_interface is MANDATORY for Suricata in IDS Mode.

However, if you want to run Suricata in Inline IPS Mode in divert(4) mode,
add to /etc/rc.conf:

        suricata_enable="YES"
        suricata_divertport="8000"

NOTE:
        Suricata won't start in IDS mode without an interface configured.
        Therefore if you omit suricata_interface from rc.conf, FreeBSD's
        rc.d/suricata will automatically try to start Suricata in IPS Mode
        (on divert port 8000, by default).

Alternatively, if you want to run Suricata in Inline IPS Mode in high-speed
netmap(4) mode, add to /etc/rc.conf:

        suricata_enable="YES"
        suricata_netmap="YES"

NOTE:
        Suricata requires additional interface settings in the configuration
        file to run in netmap(4) mode.

RULES: Suricata IDS/IPS Engine comes without rules by default. You should
add rules by yourself and set an updating strategy. To do so, please visit:

 http://www.openinfosecfoundation.org/documentation/rules.html
 http://www.openinfosecfoundation.org/documentation/emerging-threats.html

You may want to try BPF in zerocopy mode to test performance improvements:

        sysctl -w net.bpf.zerocopy_enable=1

Don't forget to add net.bpf.zerocopy_enable=1 to /etc/sysctl.conf
```

Enables on startup:
```
 > sudo vim /etc/rc.conf

 > cat /etc/rc.conf

...

suricata_enable="YES"
suricata_interface="em0"
```

Install rules:
```
 > sudo suricata-update

...

9/7/2025 -- 11:54:55 - <Info> -- Writing rules to /var/lib/suricata/rules/suricata.rules: total: 59757; enabled: 44163; added: 59757; removed 0; modified: 0
9/7/2025 -- 11:54:56 - <Info> -- Writing /var/lib/suricata/rules/classification.config
9/7/2025 -- 11:54:57 - <Info> -- Testing with suricata -T.
9/7/2025 -- 11:55:15 - <Info> -- Done.
```

Via quickstart guide and adding rules

```
 > sudo vim /usr/local/etc/suricata/suricata.yaml

 > cat /usr/local/etc/suricata/suricata.yaml
vars:
  # more specific is better for alert accuracy and performance
  address-groups:
    HOME_NET: "[192.168.33.0/24,10.0.2.0/24]"

...

af-packet:
  - interface: em0

...

default-rule-path: /var/lib/suricata/rules

rule-files:
  - suricata.rules
  - *.rules
    
...

# doesn't seem to want to run in netmap mode...
netmap:
  - interface: em0
    copy-mode: tap
    copy-iface: em0
```
    
At this point we can look at `suricata.log` and see that it's running

```
 > sudo tail /var/log/suricata/suricata.log
[100153 - Suricata-Main] 2025-07-09 05:42:26 Info: threshold-config: Threshold config parsed: 0 rule(s) found
[100153 - Suricata-Main] 2025-07-09 05:42:26 Info: detect: 44166 signatures processed. 948 are IP-only rules, 4364 are inspecting packet payload, 38632 inspect application layer, 109 are decoder event only
[100153 - Suricata-Main] 2025-07-09 12:42:41 Info: runmodes: Using 1 live device(s).
[100176 - RX#01-em0] 2025-07-09 12:42:42 Info: pcap: em0: running in 'auto' checksum mode. Detection of interface state will require 1000 packets
[100176 - RX#01-em0] 2025-07-09 12:42:42 Info: ioctl: em0: MTU 1500
[100176 - RX#01-em0] 2025-07-09 12:42:42 Info: pcap: em0: snaplen set to 1524
[100153 - Suricata-Main] 2025-07-09 12:42:43 Info: unix-manager: unix socket '/var/run/suricata/suricata-command.socket'
[100153 - Suricata-Main] 2025-07-09 12:42:43 Info: unix-manager: created socket directory /var/run/suricata/
[100153 - Suricata-Main] 2025-07-09 12:42:43 Notice: threads: Threads created -> RX: 1 W: 2 FM: 1 FR: 1   Engine started.
[100176 - RX#01-em0] 2025-07-09 12:42:59 Info: checksum: No packets with invalid checksum, assuming checksum offloading is NOT use
```
