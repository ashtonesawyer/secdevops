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
suricata_netmap="YES"
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
    HOME_NET: "[192.168.33.0/24]"

...

app-layer:
  protocols:
    ssh:
      enabled: yes
      detection-ports:
        dp: 22, 8022

...

# doesn't seem to want to run in netmap mode...
netmap:
  - interface: em0
    copy-mode: ips
    copy-iface: em0^
  - interface: em0^
    copy-mode: ips
    copy-iface: em0
```
    
At this point we can look at `suricata.log` and see that it's running

```
 > sudo tail /var/log/suricata/suricata.log
[100088 - Suricata-Main] 2025-07-13 07:10:11 Info: detect: 1 rule files processed. 44163 rules successfully loaded, 0 rules failed, 0
[100088 - Suricata-Main] 2025-07-13 07:10:11 Info: threshold-config: Threshold config parsed: 0 rule(s) found
[100088 - Suricata-Main] 2025-07-13 07:10:11 Info: detect: 44166 signatures processed. 948 are IP-only rules, 4364 are inspecting packet payload, 38632 inspect application layer, 109 are decoder event only
[100088 - Suricata-Main] 2025-07-13 14:10:22 Info: runmodes: Using 1 live device(s).
[100153 - RX#01-em0] 2025-07-13 14:10:24 Info: pcap: em0: running in 'auto' checksum mode. Detection of interface state will require 1000 packets
[100153 - RX#01-em0] 2025-07-13 14:10:24 Info: ioctl: em0: MTU 1500
[100153 - RX#01-em0] 2025-07-13 14:10:24 Info: pcap: em0: snaplen set to 1524
[100088 - Suricata-Main] 2025-07-13 14:10:24 Info: unix-manager: unix socket '/var/run/suricata/suricata-command.socket'
[100088 - Suricata-Main] 2025-07-13 14:10:24 Notice: threads: Threads created -> RX: 1 W: 2 FM: 1 FR: 1   Engine started.
[100153 - RX#01-em0] 2025-07-13 14:11:02 Info: checksum: No packets with invalid checksum, assuming checksum offloading is NOT used
```

Check if it's properly alerting (this is less thinking than figuring out what that other rules alert on...)

```
 > sudo vim /var/lib/suricata/rules/suricata.rules

 > head /var/lib/suricata/rules/suricata.rules
alert ip any any -> any any (msg:"DBG"; sid:11000000; rev:1;)
...

 > curl ifconfig.io
131.252.54.184

 > sudo cat /var/log/suricata/fast.log
...

07/14/2025-10:00:00.250423  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.15:123 -> 141.11.228.173:123
07/14/2025-10:00:00.328993  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 141.11.228.173:123 -> 10.0.2.15:123
07/14/2025-10:00:02.248333  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.15:123 -> 143.42.229.154:123
07/14/2025-10:00:02.317334  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 143.42.229.154:123 -> 10.0.2.15:123
07/14/2025-10:00:13.250081  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.15:123 -> 144.202.66.214:123
07/14/2025-10:00:13.302504  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 144.202.66.214:123 -> 10.0.2.15:123
07/14/2025-10:00:13.251883  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.15:123 -> 69.30.247.121:123
07/14/2025-10:00:13.300207  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 69.30.247.121:123 -> 10.0.2.15:123
07/14/2025-10:00:14.250867  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.15:123 -> 66.228.58.20:123
07/14/2025-10:00:14.313010  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 66.228.58.20:123 -> 10.0.2.15:123
07/14/2025-10:03:04.408615  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.15:23341 -> 10.0.2.3:53
07/14/2025-10:03:04.432146  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.3:53 -> 10.0.2.15:23341
07/14/2025-10:03:04.432841  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.15:43897 -> 10.0.2.3:53
07/14/2025-10:03:04.436552  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {UDP} 10.0.2.3:53 -> 10.0.2.15:43897
07/14/2025-10:03:04.443052  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {TCP} 10.0.2.15:54724 -> 172.67.191.233:80
07/14/2025-10:03:04.450771  [**] [1:11000000:1] DBG [**] [Classification: (null)] [Priority: 3] {TCP} 172.67.191.233:80 -> 10.0.2.15:54724
```

SMBGhost Rules
```
# from https://github.com/vncloudsco/suricata-rules/blob/main/emerging-exploit.rules
alert smb any any -> $HOME_NET any (msg:"ET EXPLOIT Possible Attempted SMB RCE Exploitation M1 (CVE-2020-0796)"; flow:established,to_server; content:"|41 8B 47 3C 4C 01 F8 8B 80 88 00 00 00 4C 01 F8 50|"; fast_pattern; reference:url,github.com/chompie1337/SMBGhost_RCE_PoC; reference:cve,2020-0796; classtype:attempted-admin; sid:2030263; rev:2; metadata:affected_product SMBv3, created_at 2020_06_08, deployment Perimeter, deployment Internal, former_category EXPLOIT, performance_impact Low, signature_severity Major, tag SMBGhost, updated_at 2020_06_08;)

alert smb any any -> $HOME_NET any (msg:"ET EXPLOIT Possible Attempted SMB RCE Exploitation M2 (CVE-2020-0796)"; flow:established,to_server; content:"|FF C9 8B 34 8B 4C 01 FE|"; fast_pattern; reference:url,github.com/chompie1337/SMBGhost_RCE_PoC; reference:cve,2020-0796; classtype:attempted-admin; sid:2030264; rev:2; metadata:affected_product SMBv3, created_at 2020_06_08, deployment Perimeter, deployment Internal, former_category EXPLOIT, performance_impact Low, signature_severity Major, tag SMBGhost, updated_at 2020_06_08;)

# from https://github.com/vncloudsco/suricata-rules/blob/main/pt-rules.rules
alert tcp any any -> any any (msg: "ATTACK [PTsecurity] CoronaBlue/SMBGhost DOS/RCE Attempt (CVE-2020-0796)"; flow: established; content: "|FC|SMB"; depth: 8; byte_test: 4, >, 0x800134, 8, relative, little; reference: url, www.mcafee.com/blogs/other-blogs/mcafee-labs/smbghost-analysis-of-cve-2020-0796; reference: cve, 2020-0796; reference: url, github.com/ptresearch/AttackDetection; classtype: attempted-admin; sid: 10005777; rev: 2;)

alert tcp any any -> any any (msg: "ATTACK [PTsecurity] CoronaBlue/SMBGhost DOS/RCE Attempt (CVE-2020-0796)"; flow: established; content: "|FC|SMB"; depth: 8; byte_test: 4, >, 0x800134, 0, relative, little; reference: url, www.mcafee.com/blogs/other-blogs/mcafee-labs/smbghost-analysis-of-cve-2020-0796; reference: cve, 2020-0796; reference: url, github.com/ptresearch/AttackDetection; classtype: attempted-admin; sid: 10005778; rev: 2;)
```
