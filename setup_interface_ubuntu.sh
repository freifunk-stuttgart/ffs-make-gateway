setup_interface_segxx() {
for seg in $SEGMENTLIST ; do
netz=$((${seg#0} - 1))
netz=$(($netz * 8))
cat <<EOF >/etc/network/interfaces.d/br$seg
auto br$seg
allow-hotplug br$seg
iface br$seg inet static
  hwaddress 02:00:39:$seg:$GWLID:$GWLSUBID
  address 10.190.$netz.$GWID$GWSUBID
  netmask 255.255.248.0
#  mtu 1280
  bridge_ports bat$seg
#  pre-up          /sbin/brctl addbr \$IFACE || true
#  up              /sbin/ip address add fd21:b4dc:4b$seg::a38:$GWLID$GWLSUBID/64 dev \$IFACE || true
#  post-down       /sbin/brctl delbr \$IFACE || true
  # be sure all incoming traffic is handled by the appropriate rt_table
  post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000 || true
  pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000 || true
  # default route is unreachable. Nur einmal
  post-up         /sbin/ip route add unreachable default table stuttgart metric 9999 || true
  post-down       /sbin/ip route del unreachable default table stuttgart metric 9999 || true

iface br$seg inet6 static
  address fd21:b4dc:4b$seg::a38:$GWLID$GWLSUBID
  netmask 64
  # ULA route mz for rt_table stuttgart
  post-up         /sbin/ip -6 route add fd21:b4dc:4b$seg::/64 proto static dev \$IFACE table stuttgart || true
  post-down       /sbin/ip -6 route del fd21:b4dc:4b$seg::/64 proto static dev \$IFACE table stuttgart || true

allow-hotplug vpn$seg
iface vpn$seg inet6 manual
  hwaddress 02:00:38:$seg:$GWLID:$GWLSUBID
  pre-up          /sbin/modprobe batman-adv || true
  pre-up          /sbin/ip link set \$IFACE address 02:00:38:$seg:$GWLID:$GWLSUBID up || true
  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
  post-up         /sbin/ip link set dev bat$seg up || true

allow-hotplug vpx$seg
iface vpx$seg inet6 manual
  hwaddress 02:00:34:$seg:$GWLID:$GWLSUBID
  pre-up          /sbin/modprobe batman-adv || true
  pre-up          /sbin/ip link set \$IFACE address 02:00:34:$seg:$GWLID:$GWLSUBID up || true
  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
  post-up         /sbin/ip link set dev bat$seg up || true

allow-hotplug vpy$seg
iface vpy$seg inet6 manual
  hwaddress 02:00:33:$seg:$GWLID:$GWLSUBID
  pre-up          /sbin/modprobe batman-adv || true
  pre-up          /sbin/ip link set \$IFACE address 02:00:33:$seg:$GWLID:$GWLSUBID up || true
  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
  post-up         /sbin/ip link set dev bat$seg up || true

allow-hotplug bb${seg}
iface bb${seg} inet6 manual
  hwaddress 02:00:35:$seg:$GWLID:$GWLSUBID
  pre-up          /sbin/modprobe batman-adv || true
  pre-up          /sbin/ip link set \$IFACE address 02:00:35:$seg:$GWLID:$GWLSUBID up || true
  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE || true
  post-up         /sbin/ip link set dev bat$seg up || true

allow-hotplug bat$seg
iface bat$seg inet6 manual
  pre-up          /sbin/modprobe batman-adv || true
  up              /usr/sbin/batctl -m \$IFACE fragmentation 0
  post-up         /sbin/brctl addif br$seg \$IFACE || true
  post-up         /sbin/ip link set dev br$seg mtu 1280 || true
  post-up         /usr/sbin/batctl -m \$IFACE it 10000 || true
  #post-up         /usr/sbin/batctl -m \$IFACE gw server  64mbit/64mbit || true
  pre-down        /sbin/brctl delif br$seg \$IFACE || true

EOF
done
}
