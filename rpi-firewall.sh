#!/bin/sh

# Warning! This firewall configuration probably got some security flaws.
# Also, It allows all forward traffic
# This was needed to use the Raspberry Pi as an Wi-Fi hotspot.
# Be aware of the ip6tables (which might be set to ALLOW for everything!)
# This script only changes the iptables of the currently running system.
# To set the configuration persistently, there are two main options:
# -- Using iptables-save > /etc/firewall.conf
#      Open up /etc/network/if-up.d/iptables and add:
#        #!/bin/sh
#        iptables-restore < /etc/firewall.conf
#      Make it executable using:
#        chmod +x /etc/network/if-up.d/iptables
#      Afterwards, you can update your persistent firewall file using:
#        iptables-save > /etc/firewall.conf
# -- Using the package iptables-persistent
# However, this is useless if you run docker because it messes iptables

# iptables binary location
IPTABLES=/usr/sbin/iptables

# Logging options.
#------------------------------------------------------------------------------
LOG="LOG --log-level debug --log-tcp-sequence --log-tcp-options"
LOG="$LOG --log-ip-options"

# Defaults for rate limiting
#------------------------------------------------------------------------------
RLIMIT="-m limit --limit 3/s --limit-burst 30"

# Default policies.
#------------------------------------------------------------------------------

# Drop everything except forward traffic by default
$IPTABLES -P INPUT DROP
$IPTABLES -P FORWARD ACCEPT
$IPTABLES -P OUTPUT DROP

# Set the nat/mangle/raw tables' chains to ACCEPT
$IPTABLES -t nat -P PREROUTING ACCEPT
$IPTABLES -t nat -P OUTPUT ACCEPT
$IPTABLES -t nat -P POSTROUTING ACCEPT

$IPTABLES -t mangle -P PREROUTING ACCEPT
$IPTABLES -t mangle -P INPUT ACCEPT
$IPTABLES -t mangle -P FORWARD ACCEPT
$IPTABLES -t mangle -P OUTPUT ACCEPT
$IPTABLES -t mangle -P POSTROUTING ACCEPT

# Cleanup.
#------------------------------------------------------------------------------

# Delete all
$IPTABLES -F
$IPTABLES -t nat -F
$IPTABLES -t mangle -F

# Delete all
$IPTABLES -X
$IPTABLES -t nat -X
$IPTABLES -t mangle -X

# Zero all packets and counters.
$IPTABLES -Z
$IPTABLES -t nat -Z
$IPTABLES -t mangle -Z

# Custom user-defined chains.
#------------------------------------------------------------------------------

# LOG packets, then ACCEPT.
$IPTABLES -N ACCEPTLOG
$IPTABLES -A ACCEPTLOG -j $LOG $RLIMIT --log-prefix "ACCEPT "
$IPTABLES -A ACCEPTLOG -j ACCEPT

# LOG packets, then DROP.
$IPTABLES -N DROPLOG
$IPTABLES -A DROPLOG -j $LOG $RLIMIT --log-prefix "DROP "
$IPTABLES -A DROPLOG -j DROP

# LOG packets, then REJECT.
# TCP packets are rejected with a TCP reset.
$IPTABLES -N REJECTLOG
$IPTABLES -A REJECTLOG -j $LOG $RLIMIT --log-prefix "REJECT "
$IPTABLES -A REJECTLOG -p tcp -j REJECT --reject-with tcp-reset
$IPTABLES -A REJECTLOG -j REJECT

# Only allows RELATED ICMP types
# (destination-unreachable, time-exceeded, and parameter-problem).
# TODO: Rate-limit this traffic?
# TODO: Allow fragmentation-needed?
# TODO: Test.
$IPTABLES -N RELATED_ICMP
$IPTABLES -A RELATED_ICMP -p icmp --icmp-type destination-unreachable -j ACCEPT
$IPTABLES -A RELATED_ICMP -p icmp --icmp-type time-exceeded -j ACCEPT
$IPTABLES -A RELATED_ICMP -p icmp --icmp-type parameter-problem -j ACCEPT
$IPTABLES -A RELATED_ICMP -j DROPLOG

# Make It Even Harder To Multi-PING
$IPTABLES  -A INPUT -p icmp -m limit --limit 1/s --limit-burst 2 -j ACCEPT
$IPTABLES  -A OUTPUT -p icmp -j ACCEPT

# Only allow the minimally required/recommended parts of ICMP. Block the rest.
#------------------------------------------------------------------------------

# Allow all ESTABLISHED ICMP traffic.
$IPTABLES -A INPUT -p icmp -m state --state ESTABLISHED -j ACCEPT $RLIMIT
$IPTABLES -A OUTPUT -p icmp -m state --state ESTABLISHED -j ACCEPT $RLIMIT

# Allow some parts of the RELATED ICMP traffic, block the rest.
$IPTABLES -A INPUT -p icmp -m state --state RELATED -j RELATED_ICMP $RLIMIT
$IPTABLES -A OUTPUT -p icmp -m state --state RELATED -j RELATED_ICMP $RLIMIT

# Allow incoming ICMP echo requests (ping), but only rate-limited.
$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT $RLIMIT

# Allow outgoing ICMP echo requests (ping), but only rate-limited.
$IPTABLES -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT $RLIMIT

# Drop any other ICMP traffic.
$IPTABLES -A INPUT -p icmp -j DROPLOG
$IPTABLES -A OUTPUT -p icmp -j DROPLOG
#$IPTABLES -A FORWARD -p icmp -j DROPLOG

# Selectively allow certain special types of traffic.
#------------------------------------------------------------------------------

# Allow loopback interface to do anything.
$IPTABLES -A INPUT --in-interface lo -j ACCEPT
$IPTABLES -A OUTPUT --out-interface lo -j ACCEPT

# Allow incoming connections related to existing allowed connections.
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing connections EXCEPT invalid
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Anti-attack.
#------------------------------------------------------------------------------

# Anti-spoofing (deny packets that claim to come from localhost, but are not coming from loopback)
$IPTABLES -A INPUT ! --in-interface lo --source 127.0.0.0/8 -j DROP
# Drop bogus packets
$IPTABLES -A INPUT   -m state --state INVALID -j DROP
$IPTABLES -A FORWARD -m state --state INVALID -j DROP
$IPTABLES -A OUTPUT  -m state --state INVALID -j DROP
$IPTABLES -t filter -A INPUT -p tcp --tcp-flags FIN,ACK FIN -j DROP
$IPTABLES -t filter -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j DROP
$IPTABLES -t filter -A INPUT -p tcp --tcp-flags ACK,URG URG -j DROP
$IPTABLES -t filter -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
$IPTABLES -t filter -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPTABLES -t filter -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IPTABLES -t filter -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP

# Selectively allow certain outbound connections, block the rest.
#------------------------------------------------------------------------------

# Erlaube ausgehende DNS Anfragen. Few things will work without this.
$IPTABLES -A OUTPUT -m state --state NEW -p udp --dport 53 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 53 -j ACCEPT

# Erlaube ausgehende HTTP Anfragen.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT

# Erlaube ausgehende HTTPS Anfragen.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Erlaube ausgehende SMTP Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT

# Erlaube ausgehende SMTPS Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 465 -j ACCEPT

# Erlaube ausgehende "submission" (RFC 2476) Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 587 -j ACCEPT

# Erlaube ausgehende POP3S Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 995 -j ACCEPT

# Erlaube ausgehende SSH Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT

# Erlaube ausgehende FTP Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT

# Erlaube ausgehende NTP Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p udp --dport 123 -j ACCEPT

# Erlaube ausgehende WHOIS Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 43 -j ACCEPT

# Erlaube ausgehende CVS Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 2401 -j ACCEPT

# Erlaube ausgehende MySQL Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 3306 -j ACCEPT

# Erlaube ausgehende SVN Anfragen.
# $IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 3690 -j ACCEPT

# Erlaube ausgehende Mumble Anfragen.
#$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 64738 -j ACCEPT
#$IPTABLES -A OUTPUT -m state --state NEW -p udp --dport 64738 -j ACCEPT

# Erlaube ausgehende VPN-UDP Anfragen
$IPTABLES -A OUTPUT -m state --state NEW -p udp --dport 443 -j ACCEPT

# Selectively allow certain inbound connections, block the rest.
#------------------------------------------------------------------------------

# Erlaube eingehende DNS Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p udp --dport 53 -j ACCEPT
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 53 -j ACCEPT

# Erlaube eingehende HTTP Anfragen.
$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT

# Erlaube eingehende HTTPS Anfragen.
$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Erlaube eingehende POP3 Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 110 -j ACCEPT

# Erlaube eingehende IMAP4 Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 143 -j ACCEPT

# Erlaube eingehende POP3S Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 995 -j ACCEPT

# Erlaube eingehende SMTP Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT

# Erlaube eingehende SSH Anfragen.
$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT

# Erlaube eingehende FTP Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT

# Erlaube eingehende Mumble-Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 64738 -j ACCEPT
#$IPTABLES -A INPUT -m state --state NEW -p udp --dport 64738 -j ACCEPT

# Erlaube eingehende MySQL Anfragen.
#$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 3306 -j ACCEPT

# Erlaube eingehende PRIVOXY Anfragen.
$IPTABLES -A INPUT -m state --state NEW -p tcp --dport 8118 -j ACCEPT

# Explicitly log and reject everything else.
#------------------------------------------------------------------------------
# Use REJECT instead of REJECTLOG if you don't need/want logging.
$IPTABLES -A INPUT -j REJECT
$IPTABLES -A OUTPUT -j REJECT
#$IPTABLES -A FORWARD -j REJECT

# Exit gracefully.
#------------------------------------------------------------------------------

    exit 0

