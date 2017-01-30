setup_interface_segxx() {
for seg in $SEGMENTLIST ; do
netz=$((${seg#0} - 1))
netz=$(($netz * 8))
cat <<EOF >/etc/network/interfaces.d/br$seg
auto br$seg
iface br$seg inet static
  hwaddress 02:00:39:$seg:$GWLID:$GWLSUBID
  address 10.190.$netz.$GWID$GWSUBID
  netmask 255.255.248.0
  pre-up          /sbin/brctl addbr \$IFACE
  up              /sbin/ip address add fd21:b4dc:4b$seg::a38:$GWLID$GWLSUBID/64 dev \$IFACE
  post-down       /sbin/brctl delbr \$IFACE
  # be sure all incoming traffic is handled by the appropriate rt_table
  post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000
  pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000
  # ULA route mz for rt_table stuttgart
  post-up         /sbin/ip -6 route add fd21:b4dc:4b$seg::/64 proto static dev \$IFACE table stuttgart
  post-down       /sbin/ip -6 route del fd21:b4dc:4b$seg::/64 proto static dev \$IFACE table stuttgart
  # default route is unreachable. Nur einmal
  post-up         /sbin/ip route add unreachable default table stuttgart
  post-down       /sbin/ip route del unreachable default table stuttgart

allow-hotplug vpn$seg
iface vpn$seg inet6 manual
  hwaddress 02:00:38:$seg:$GWLID:$GWLSUBID
  pre-up          /sbin/modprobe batman-adv
  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE
  post-up         /sbin/ip link set dev bat$seg up

allow-hotplug vpn${seg}bb
iface vpn${seg}bb inet6 manual
  hwaddress 02:00:35:$seg:$GWLID:$GWLSUBID
  pre-up          /sbin/modprobe batman-adv
  post-up         /usr/sbin/batctl -m bat$seg if add \$IFACE
  post-up         /sbin/ip link set dev bat$seg up

allow-hotplug bat$seg
iface bat$seg inet6 manual
  pre-up          /sbin/modprobe batman-adv
  post-up         /sbin/brctl addif br$seg \$IFACE
  post-up         /usr/sbin/batctl -m \$IFACE it 10000
  #post-up         /usr/sbin/batctl -m \$IFACE gw server  64mbit/64mbit
  pre-down        /sbin/brctl delif br$seg \$IFACE || true

EOF
done
}
