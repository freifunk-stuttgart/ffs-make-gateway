get_netmask_for_seg() {
	seg=$1
	if [ $seg -eq 33 ]; then
		echo 19
		return
	fi
	echo 21
}
get_gwaddr_for_seg() {
	seg=$1
	netz=$((${seg#0} - 1))
	netz=$(($netz * 8))
	if [ $seg -eq 33 ]; then
		echo 10.191.0.$GWID$GWSUBID
		return
	fi
	echo 10.190.$netz.$GWID$GWSUBID
}
get_net_for_seg() {
	seg=$1
	netz=$((${seg#0} - 1))
	netz=$(($netz * 8))
	netmask=$(get_netmask_for_seg "$seg")
	if [ $seg -eq 33 ]; then
		echo 10.191.0.0/$netmask
		return
	fi
	echo 10.190.$netz.0/$netmask
}
setup_interface_segxx() {
for seg in $SEGMENTLIST ; do
  netz=$((${seg#0} - 1))
  netz=$(($netz * 8))
  seghex=$(printf %02x ${seg#0})
  cat <<-EOF >/etc/network/interfaces.d/br$seg
	allow-hotplug br$seg
	iface br$seg inet static
	  bridge_hw 02:00:39:$seg:$GWLID:$GWLSUBID
	  address $(get_gwaddr_for_seg "$seg")
	  netmask $(get_netmask_for_seg "$seg")
	  bridge_ports bat$seg tap$seg
	  bridge_fd 0
	  bridge_maxwait 0
	  mtu 1500
	  # be sure all incoming traffic is handled by the appropriate rt_table
	  post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000 || true
	  pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000 || true
	  # doesn't belong here, no delete because it should never go away
	  post-up         /sbin/ip -6 rule add from all table stuttgart priority 7000 || true
	  post-up         /sbin/ip rule add iif \$IFACE table ffsdefault priority 10000 || true
	  pre-down        /sbin/ip rule del iif \$IFACE table ffsdefault priority 10000 || true
	  post-up         /sbin/ip -6 rule add iif \$IFACE table ffsdefault priority 10000 || true
	  pre-down        /sbin/ip -6 rule del iif \$IFACE table ffsdefault priority 10000 || true
	  # asume multicast router, see https://gluon.readthedocs.io/en/latest/package/gluon-mesh-batman-adv.html?highlight=multicast#igmp-mld-domain-segmentation
	  post-up         echo 2 > /sys/class/net/bat$seg/brport/multicast_router || true
	EOF
  if [ $PROVIDERMODE -eq 0 ]; then
    cat <<-EOF >>/etc/network/interfaces.d/br$seg
	  post-up         /sbin/ip rule add iif \$IFACE table nodefault priority 10001 || true
	  pre-down        /sbin/ip rule del iif \$IFACE table nodefault priority 10001 || true
	EOF
  fi
  cat <<-EOF >>/etc/network/interfaces.d/br$seg
	  post-up         iptables -t mangle -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || true
	  post-up         ip6tables -t mangle -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || true
	  post-down       iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || true
	  post-down       ip6tables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || true
	  # default route is unreachable
	  post-up         /sbin/ip route add $(get_net_for_seg "$seg") dev \$IFACE table stuttgart || true
	  post-up         /sbin/ip route add unreachable default table nodefault || true
	  post-down       /sbin/ip route del unreachable default table nodefault || true
	  post-down       /sbin/ip route del $(get_net_for_seg "$seg") dev \$IFACE table stuttgart || true
	  post-up         /sbin/ip addr add fd21:b4dc:4b$seg::a38:$GWLID$GWLSUBID/64 dev \$IFACE || true
	  post-up         /sbin/ip -6 route add fd21:b4dc:4b$seg::/64 proto static dev \$IFACE table stuttgart || true
	  post-down       /sbin/ip -6 route del fd21:b4dc:4b$seg::/64 proto static dev \$IFACE table stuttgart || true
	  post-down       /sbin/ip addr del fd21:b4dc:4b$seg::a38:$GWLID$GWLSUBID/64 dev \$IFACE || true
EOF
if [ ! -z $IP6 ]; then
cat <<-EOF >>/etc/network/interfaces.d/br$seg
	  post-up         /sbin/ip addr add $IP6$seghex::$GWLID$GWLSUBID/64 dev \$IFACE || true
	  post-down       /sbin/ip addr del $IP6$seghex::$GWLID$GWLSUBID/64 dev \$IFACE || true
EOF
fi
cat <<-EOF >>/etc/network/interfaces.d/br$seg
	auto bat$seg
	iface bat$seg inet6 manual
	  mtu 1500
          up              /usr/sbin/batctl -m \$IFACE if create || true
	  pre-up          /sbin/modprobe batman-adv || true
	  post-up         /usr/sbin/batctl -m \$IFACE it 10000 || true
	  post-up         /usr/sbin/batctl -m \$IFACE gw server  64mbit/64mbit || true
	
	iface vpn$seg inet6 manual
	  pre-up          /sbin/modprobe batman-adv || true
	  pre-up          /sbin/ip link set \$IFACE address 02:00:38:$seg:$GWLID:$GWLSUBID up || true
	  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
	  post-up         ifup br$seg || true
	
	iface vpy${seg} inet6 manual
	  pre-up          /sbin/modprobe batman-adv || true
	  pre-up          /sbin/ip link set \$IFACE address 02:00:33:$seg:$GWLID:$GWLSUBID up || true
	  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
	  post-up         ifup br$seg || true
	
	iface bb${seg} inet6 manual
	  pre-up          /sbin/modprobe batman-adv || true
	  pre-up          /sbin/ip link set \$IFACE address 02:00:35:$seg:$GWLID:$GWLSUBID up || true
	  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
	  post-up         ifup br$seg || true
	
	EOF
	if [ "$LOCAL_SEGMENT" == "$seg" ]; then
	  for iface in $LOCAL_SEGMENT_INTERFACES; do
            cat <<-EOF >>/etc/network/interfaces.d/br$seg
	allow-hotplug $iface
	iface $iface inet6 manual
	  pre-up          /sbin/modprobe batman-adv || true
	  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
	  post-up         ifup br$seg || true
	EOF
	  done
	fi
  done
}
