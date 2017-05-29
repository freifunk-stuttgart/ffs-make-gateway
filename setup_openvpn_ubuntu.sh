setup_openvpn() {
cat <<-EOF >/usr/local/bin/switch-vpn
#! /bin/bash
ovpn=/etc/openvpn
prg=openvpn

# Config wechseln
echo "Config rotieren!"
mv \$ovpn/00.conf \$ovpn/00.ovpn
mv \$ovpn/01.ovpn \$ovpn/00.conf
mv \$ovpn/02.ovpn \$ovpn/01.ovpn
mv \$ovpn/00.ovpn \$ovpn/02.ovpn
service \$prg restart
EOF
chmod +x /usr/local/bin/switch-vpn

cat <<-EOF >/etc/openvpn/openvpn-up
#!/bin/sh
ip rule add from \$ifconfig_local table stuttgart priority 9970
ip route add 0.0.0.0/1 via \$route_vpn_gateway dev \$dev table stuttgart
ip route add 128.0.0.0/1 via \$route_vpn_gateway dev \$dev table stuttgart
# NAT aktivieren und NAT Tabelle vergroessern, wird benötigt wenn NICHT Berlin
iptables -t nat -A POSTROUTING -o \$dev -j MASQUERADE
sysctl -w net.netfilter.nf_conntrack_max=500000
#exit 0
EOF

if [ "x$DIRECTTCP" != "x" ]; then
cat <<-EOF >>/etc/openvpn/openvpn-up
# https+Mailports direkt ausleiten
ip rule add fwmark 0x2000 lookup direct priority 6000
iptables -t mangle -A PREROUTING -j MARK --set-xmark 0x0/0xffffffff
iptables -t mangle -A FORWARD -j MARK --set-xmark 0x0/0xffffffff
for port in $DIRECTTCP; do
  iptables -t mangle -A PREROUTING -s 10.190.0.0/15 -p tcp -m tcp --dport \$port -j MARK --set-xmark 0x2000/0xffffffff
  iptables -t mangle -A FORWARD -s 10.190.0.0/15 -p tcp -m tcp --dport \$port -j MARK --set-xmark 0x2000/0xffffffff
  iptables -t nat -A POSTROUTING -o $EXT_IF_V4 -p tcp --dport \$port -j SNAT --to-source $EXT_IP_V4
done
ip route show table main | while read ROUTE ; do ip route add table direct \$ROUTE ; done
exit 0
EOF
fi
chmod +x /etc/openvpn/openvpn-up
cat <<-EOF >/etc/openvpn/openvpn-down
#!/bin/sh
ip rule del from \$ifconfig_local table stuttgart priority 9970
# NAT deaktivieren, wird benötigt wenn NICHT Berlin
iptables -t nat -D POSTROUTING -o \$dev -j MASQUERADE
#exit 0

# https+Mailports direkt ausleiten
ip rule del fwmark 0x2000 lookup direct priority 6000
for port in $DIRECTTCP; do
  iptables -t mangle -D PREROUTING -s 10.190.0.0/15 -p tcp -m tcp --dport \$port -j MARK --set-xmark 0x2000/0xffffffff
  iptables -t nat -D POSTROUTING -o $EXT_IF_V4 -p tcp --dport \$port -j SNAT --to-source $EXT_IP_V4
done
iptables -t mangle -D PREROUTING -j MARK --set-xmark 0x0/0xffffffff
ip route flush table direct
exit 0
EOF
chmod +x /etc/openvpn/openvpn-down
# Config anpassen
ensureline "route-noexec" /etc/openvpn/00.conf
ensureline "script-security 2" /etc/openvpn/00.conf
ensureline_tr "up \"openvpn-up\"" /etc/openvpn/00.conf
ensureline_tr "down \"openvpn-down\"" /etc/openvpn/00.conf
ensureline "sndbuf 393216" /etc/openvpn/00.conf
ensureline "rcvbuf 393216" /etc/openvpn/00.conf
ensureline_tr "push \"sndbuf 393216\"" /etc/openvpn/00.conf
ensureline_tr "push \"rcvbuf 393216\"" /etc/openvpn/00.conf
ensureline "route-noexec" /etc/openvpn/01.ovpn
ensureline "script-security 2" /etc/openvpn/01.ovpn
ensureline_tr "up \"openvpn-up\"" /etc/openvpn/01.ovpn
ensureline_tr "down \"openvpn-down\"" /etc/openvpn/01.ovpn
ensureline "sndbuf 393216" /etc/openvpn/01.ovpn
ensureline "rcvbuf 393216" /etc/openvpn/01.ovpn
ensureline_tr "push \"sndbuf 393216\"" /etc/openvpn/01.ovpn
ensureline_tr "push \"rcvbuf 393216\"" /etc/openvpn/01.ovpn
ensureline "route-noexec" /etc/openvpn/02.ovpn
ensureline "script-security 2" /etc/openvpn/02.ovpn
ensureline_tr "up \"openvpn-up\"" /etc/openvpn/02.ovpn
ensureline_tr "down \"openvpn-down\"" /etc/openvpn/02.ovpn
ensureline "sndbuf 393216" /etc/openvpn/02.ovpn
ensureline "rcvbuf 393216" /etc/openvpn/02.ovpn
ensureline_tr "push \"sndbuf 393216\"" /etc/openvpn/02.ovpn
ensureline_tr "push \"rcvbuf 393216\"" /etc/openvpn/02.ovpn

}

