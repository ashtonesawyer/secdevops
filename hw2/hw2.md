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

```pf.conf
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

```pf.conf
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
