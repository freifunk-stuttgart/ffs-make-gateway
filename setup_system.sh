setup_system_sysctl() {
cat <<EOF >/etc/sysctl.d/999-freifunk.conf
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0

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
net.ipv6.conf.all.forwarding=1

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

net.core.netdev_budget=3000
EOF
sysctl -p /etc/sysctl.d/999-freifunk.conf || true
}
setup_system_sysfs() {
	for seg in $SEGMENTLIST; do
		echo class/net/br$seg/bridge/hash_max = 4096
		echo class/net/bat$seg/mesh/hop_penalty = 60
	done > /etc/sysfs.d/freifunk.conf
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
