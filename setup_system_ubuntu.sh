setup_system_sysctl() {
cat <<EOF >/etc/sysctl.d/999-freifunk.conf
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.all.rp_filter=0
net.core.netdev_budget=1000
net.ipv4.neigh.default.gc_thresh1 = 1280
net.ipv4.neigh.default.gc_thresh2 = 5120
net.ipv4.neigh.default.gc_thresh3 = 10240
net.ipv6.neigh.default.gc_thresh1 = 1280
net.ipv6.neigh.default.gc_thresh2 = 5120
net.ipv6.neigh.default.gc_thresh3 = 10240

# neu von are
kernel.panic=3
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.arp_ignore=1
net.ipv4.conf.all.arp_ignore=1
net.ipv4.ip_forward=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.igmp_max_memberships=100
net.ipv4.tcp_ecn=0
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=120
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_dsack=1

net.ipv6.conf.default.forwarding=1

net.netfilter.nf_conntrack_acct=1
net.netfilter.nf_conntrack_checksum=0
net.netfilter.nf_conntrack_max=1000000
net.netfilter.nf_conntrack_tcp_timeout_established=7440
net.netfilter.nf_conntrack_udp_timeout=60
net.netfilter.nf_conntrack_udp_timeout_stream=180

# disable bridge firewalling by default
net.bridge.bridge-nf-call-arptables=0
net.bridge.bridge-nf-call-ip6tables=0
net.bridge.bridge-nf-call-iptables=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
vm.panic_on_oom=1

EOF
sysctl -p /etc/sysctl.d/999-freifunk.conf || true
}

setup_system_sysfs() {
cat <<EOF >/etc/sysfs.d/99-freifunk.conf
# increase batman-adv hop penalty (default=15)
# increase multicast hash table of freifunk bridges (default=512)
EOF
for seg in $SEGMENTLIST ; do
cat <<EOF >>/etc/sysfs.d/99-freifunk.conf
class/net/bat$seg/mesh/hop_penalty = 60
class/net/br$seg/bridge/hash_max = 2048
class/net/br$seg/brport/multicast_router = 2
EOF
done
service sysfsutils restart || true
}

setup_system_routing() {
  ensureline "42  icvpn" /etc/iproute2/rt_tables
  ensureline "70  stuttgart" /etc/iproute2/rt_tables
  ensureline "71  nodefault" /etc/iproute2/rt_tables
  ensureline "1000  othergw" /etc/iproute2/rt_tables
  ensureline "2000  direct" /etc/iproute2/rt_tables
  ensureline "3000  ffsdefault" /etc/iproute2/rt_tables
}

setup_system_autostart() {
if [ -f /etc/rc.local ]; then
  ensureline "/usr/local/bin/autostart &" /etc/rc.local
else
  cat <<EOF >/etc/rc.local
#!/bin/sh -e
/usr/local/bin/autostart &
exit 0
EOF
  chmod +x /etc/rc.local
fi
cat <<EOF >/usr/local/bin/autostart
#!/bin/bash
# wird beim booten einmal gestartet
# default Route in direct Tabelle hinzufügen
back=\$(ip r | grep default)
/sbin/ip route add \$back table direct
# sinkhole shadowserver
for ship in 184.105.192.2 178.162.203.211 178.162.203.226 ;do
  /sbin/ip route add \$ship dev lo table ffsdefault
done
# IPs not allowed in internet
for ship in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/3 ;do
  /sbin/ip route add \$ship dev lo table ffsdefault
done
EOF
if [ "$PROVIDERMODE" -ne 0 ]; then
cat <<EOF >>/usr/local/bin/autostart
/sbin/ip route add default via $EXT_GW_V4 dev $EXT_IF_V4 table ffsdefault
EOF
fi
cat <<EOF >>/usr/local/bin/autostart
# flush all chains
#iptables -F
#iptables -t nat -F
iptables -t mangle -F
# delete all chains
#iptables -X
# MTU Fixes
/sbin/iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1240
/sbin/iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
/sbin/ip6tables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1220
/sbin/ip6tables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
EOF
chmod +x /usr/local/bin/autostart
}
