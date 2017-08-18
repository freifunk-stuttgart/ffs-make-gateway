setup_system_sysctl() {
cat <<EOF >/etc/sysctl.d/999-freifunk.conf
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.all.rp_filter=0
EOF
sysctl -p /etc/sysctl.d/999-freifunk.conf || true
}

setup_system_sysfs() {
cat <<EOF >/etc/sysfs.d/99-freifunk.conf
# increase batman-adv hop penalty (default=15)
class/net/bat01/mesh/hop_penalty = 60
class/net/bat02/mesh/hop_penalty = 60
class/net/bat03/mesh/hop_penalty = 60
class/net/bat04/mesh/hop_penalty = 60

# increase multicast hash table of freifunk bridges (default=512)
class/net/br01/bridge/hash_max = 2048
class/net/br02/bridge/hash_max = 2048
class/net/br03/bridge/hash_max = 2048
class/net/br04/bridge/hash_max = 2048
EOF
}

setup_system_sysfs() {
cat <<EOF >/etc/sysfs.d/99-freifunk.conf
# increase batman-adv hop penalty (default=15)
class/net/bat01/mesh/hop_penalty = 60
class/net/bat02/mesh/hop_penalty = 60
class/net/bat03/mesh/hop_penalty = 60
class/net/bat04/mesh/hop_penalty = 60

# increase multicast hash table of freifunk bridges (default=512)
class/net/br01/bridge/hash_max = 2048
class/net/br02/bridge/hash_max = 2048
class/net/br03/bridge/hash_max = 2048
class/net/br04/bridge/hash_max = 2048
EOF
}

setup_system_routing() {
  ensureline "42  icvpn" /etc/iproute2/rt_tables
  ensureline "70  stuttgart" /etc/iproute2/rt_tables
  ensureline "71  nodefault" /etc/iproute2/rt_tables
  ensureline "1000  othergw" /etc/iproute2/rt_tables
  ensureline "2000  direct" /etc/iproute2/rt_tables
}

setup_system_autostart() {
  ensureline "/usr/local/bin/autostart &" /etc/rc.local
cat <<EOF >/usr/local/bin/autostart
#!/bin/bash
# wird beim booten einmal gestartet
# MTU Fixes
/sbin/iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1240
/sbin/iptables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
/sbin/ip6tables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1220
/sbin/ip6tables -t mangle -A FORWARD -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
EOF
chmod +x /usr/local/bin/autostart
}
