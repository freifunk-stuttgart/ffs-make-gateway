setup_openvpn() {
cat <<-EOF >/usr/local/bin/switch-vpn
#! /bin/bash
ovpn=/etc/openvpn
prg=openvpn

# Config wechseln
echo "Config rotieren!"
mv $ovpn/00.conf $ovpn/00.ovpn
mv $ovpn/01.ovpn $ovpn/00.conf
mv $ovpn/02.ovpn $ovpn/01.ovpn
mv $ovpn/03.ovpn $ovpn/02.ovpn
mv $ovpn/00.ovpn $ovpn/03.ovpn
service $prg restart
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
exit 0
EOF
chmod +x /etc/openvpn/openvpn-up
cat <<-EOF >/etc/openvpn/openvpn-down
#!/bin/sh
ip rule del from \$ifconfig_local table stuttgart priority 9970
# NAT deaktivieren, wird benötigt wenn NICHT Berlin
iptables -t nat -D POSTROUTING -o \$dev -j MASQUERADE
exit 0
EOF
chmod +x /etc/openvpn/openvpn-down
# Config anpassen
ensureline "route-noexec" /etc/openvpn/00.conf
ensureline "script-security 2" /etc/openvpn/00.conf
ensureline "up \"openvpn-up\"" /etc/openvpn/00.conf
ensureline "down \"openvpn-down\"" /etc/openvpn/00.conf

}

