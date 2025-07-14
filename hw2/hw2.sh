#!/bin/sh
#
# To download this script directly from freeBSD:
# $ pkg install curl
# $ curl -LO https://web.cecs.pdx.edu/~dmcgrath/courses/freebsd_setup.sh
#
#The following features are added:
# - switching (internal to the network) via FreeBSD pf
# - DHCP server, DNS server via dnsmasq
# - firewall via FreeBSD pf
# - NAT layer via FreeBSD pf
#

# Set your network interfaces names; set these as they appear in ifconfig
# they will not be renamed during the course of installation
WAN="em0"
LAN="em1"

# Install dnsmasq
sudo pkg install -y dnsmasq shfmt groff eza tmux zsh vim emacs git groff gdb bat figlet filters cowsay lolcat fontforge doxygen gawk hexyl sipcalc direnv wireshark tcpdump ruby ruby32-gems pyenv atuin fastfetch sunwait diff-so-fancy btop autojump fzf cmake bat-extras

if [ $? -ne 0 ]; then
    echo "Failed to install packages"
    exit 1
fi

sudo gem install colorls mdless

if [ $? -ne 0 ]; then
    echo "Failed to install gems"
    exit 1
fi


# Enable forwarding
sudo sysrc gateway_enable="YES"
# Enable immediately
sudo sysctl net.inet.ip.forwarding=1

# Set LAN IP
sudo ifconfig ${LAN} inet 192.168.33.1 netmask 255.255.255.0
# Make IP setting persistent
sudo sysrc "ifconfig_${LAN}=inet 192.168.33.1 netmask 255.255.255.0"

sudo ifconfig ${LAN} up
sudo ifconfig ${LAN} promisc

# Enable dnsmasq on boot
sudo sysrc dnsmasq_enable="YES"

# Edit dnsmasq configuration
grep -q "interface=em1" /usr/local/etc/dnsmasq.conf || echo "interface=${LAN}" | sudo tee -a /usr/local/etc/dnsmasq.conf
grep -q "^dhcp-range" /usr/local/etc/dnsmasq.conf || echo "dhcp-range=192.168.33.50,192.168.33.150,12h" | sudo tee -a /usr/local/etc/dnsmasq.conf
grep -q "^dhcp-option" /usr/local/etc/dnsmasq.conf || echo "dhcp-option=option:router,192.168.33.1" | sudo tee -a /usr/local/etc/dnsmasq.conf

# Configure PF for NAT
echo "
ext_if=\"${WAN}\"
int_if=\"${LAN}\"

icmp_types = \"{ echoreq, unreach }\"
services = \"{ ssh, domain, http, ntp, https }\"
server = \"192.168.33.69\"
ssh_rdr = \"2222\"
table <rfc6890> { 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16          \\
                  172.16.0.0/12 192.0.0.0/24 192.0.0.0/29 192.0.2.0/24 192.88.99.0/24    \\
                  192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24            \\
                  240.0.0.0/4 255.255.255.255/32 }
table <bruteforce> persist


#options
set skip on lo0

#normalization
scrub in all fragment reassemble max-mss 1440

#NAT rules
nat on \$ext_if from \$int_if:network to any -> (\$ext_if)

#redirect rules
rdr pass log on \$ext_if inet proto tcp form any to port ssh -> \$server port ssh

#blocking rules
antispoof quick for \$ext_if
block in quick log on egress from <rfc6890>
block return out quick log on egress to <rfc6890>
block log all

#pass rules
pass in quick on \$int_if inet proto udp from any port = bootpc to 255.255.255.255 port = bootps keep state label \"allow access to DHCP server\"
pass in quick on \$int_if inet proto udp from any port = bootpc to \$int_if:network port = bootps keep state label \"allow access to DHCP server\"
pass out quick on \$int_if inet proto udp from \$int_if:0 port = bootps to any port = bootpc keep state label \"allow access to DHCP server\"

pass in quick on \$ext_if inet proto udp from any port = bootps to \$ext_if:0 port = bootpc keep state label \"allow access to DHCP client\"
pass out quick on \$ext_if inet proto udp from \$ext_if:0 port = bootpc to any port = bootps keep state label \"allow access to DHCP client\"

pass in on \$ext_if proto tcp to port { ssh, 8022 } keep state (max-src-conn 15, max-src-conn-rate 3/1, overload <bruteforce> flush global)
pass out on \$ext_if proto { tcp, udp } to port \$services
pass out on \$ext_if inet proto icmp icmp-type \$icmp_types
pass in on \$int_if from \$int_if:network to any
pass out on \$int_if from \$int_if:network to any

pass out on \$int_if proto tcp from any to \$server port { ssh } keep state
" | sudo tee /etc/pf.conf

# Start dnsmasq
sudo service dnsmasq start

# Enable PF on boot
sudo sysrc pf_enable="YES"
sudo sysrc pflog_enable="YES"

# Start PF
sudo service pf start

# Load PF rules
sudo pfctl -f /etc/pf.conf

sudo sed -i '' 's/#PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo service sshd restart

hostname | xargs echo -n > ethers.txt
echo -n ',' >> ethers.txt
ifconfig "$WAN" | awk -v wan="$WAN" '/ether/ {print wan" ← "$2}' | xargs echo -n >> ethers.txt
echo -n ',' >> ethers.txt
ifconfig "$LAN" | awk -v lan="$LAN" '/ether/ {print lan" → "$2}' >> ethers.txt

pyenv install 3.12.6
pyenv global 3.12.6

eval "$(pyenv init -)"

pip install --upgrade pip requests python-dateutil

if [ ! -e $HOME/antigen.zsh ]; then
    curl -L git.io/antigen > $HOME/antigen.zsh
fi

if [ ! -d $HOME/.tmux/plugins/tpm ]; then
    mkdir -p $HOME/.tmux/plugins/tpm
    git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
fi

if [ ! -d $HOME/.oh-my-zsh ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git $HOME/.oh-my-zsh
fi

if [ ! -d $HOME/clones/astral ]; then
    git clone https://github.com/sffjunkie/astral.git $HOME/clones/astral
fi

if [ ! -e $HOME/.zshrc.local ]; then
    curl http://web.cecs.pdx.edu/~dmcgrath/setup_freebsd.tar.bz2 | tar xjvf - -C ~/    
fi

# set the default shell to zsh
sudo chsh -s /usr/local/bin/zsh $LOGNAME

###############=====================################
###############= git configuration =################
git config unset --global user.name
#fill in and uncomment the next two lines!
#git config --global user.name ""
#git config --global user.email ""
git config get --global user.name > /dev/null
if [ $? -ne 0 ]; then
    echo "Please set your git user.name and user.email!"
    echo "You were prompted to do this, but you didn't!"
    echo "git config --global user.name \"Your Name Here\""
    echo "git config --global user.email \"ODIN@pdx.edu\""
    echo "DO NOT RUN THIS SCRIPT AGAIN UNLESS YOU UNDERSTAND THE CONSEQUENCES!"
fi

git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
git config --global interactive.diffFilter "diff-so-fancy --patch"
git config --global color.ui true
git config --global color.diff-highlight.oldNormal    "red bold"
git config --global color.diff-highlight.oldHighlight "red bold 52"
git config --global color.diff-highlight.newNormal    "green bold"
git config --global color.diff-highlight.newHighlight "green bold 22"
git config --global color.diff.meta       "11"
git config --global color.diff.frag       "magenta bold"
git config --global color.diff.func       "146 bold"
git config --global color.diff.commit     "yellow bold"
git config --global color.diff.old        "red bold"
git config --global color.diff.new        "green bold"
git config --global color.diff.whitespace "red reverse"

echo "DO NOT RUN THIS SCRIPT AGAIN UNLESS YOU UNDERSTAND THE CONSEQUENCES!"

echo "You may need to run the following commands to finish setting up your environment:"
echo " cd .antigen/bundles/romkatv/powerlevel10k/gitstatus"
echo " ./build -s -w"
