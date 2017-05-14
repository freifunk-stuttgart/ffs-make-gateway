setup_tinc_config() {
if [ ! -d /root/tinc-ffsbb/.git ]; then
  git clone https://github.com/freifunk-stuttgart/tinc-ffsbb /root/tinc-ffsbb
fi
if [ ! -d /etc/tinc/ffsbb ]; then
    mkdir -p /etc/tinc/ffsbb/hosts
fi
cat <<EOF >/etc/tinc/ffsbb/tinc.conf
Name = $HOSTNAME
ConnectTo = dhcp01
ConnectTo = dhcp02
ConnectTo = dhcp03
ConnectTo = gw05n01
ConnectTo = gw08n04
ConnectTo = gw08n05
Mode = switch
Port = 6551
#GraphDumpFile = /tmp/ffsbb.gv
EOF
cat <<EOF >/etc/tinc/ffsbb/tinc-up
#!/bin/sh
ip addr add 10.191.255.$GWID$GWSUBID/24 broadcast 10.191.255.255 dev \$INTERFACE
ip link set \$INTERFACE up
ip rule add iif \$INTERFACE table stuttgart priority 7000
ip route add 10.191.255.0/24 proto kernel scope link src 10.191.255.$GWID$GWSUBID dev \$INTERFACE table stuttgart
ip route add 10.190.0.0/15 dev \$INTERFACE metric 256
ip route add 10.190.0.0/15 dev \$INTERFACE metric 256 table stuttgart
ip addr add fd21:b4dc:4b00::a38:$GWLID$GWLSUBID/128 dev \$INTERFACE
ip route add fd21:b4dc:4b00::/40 dev \$INTERFACE metric 1024
ip route add fd21:b4dc:4b00::/40 dev \$INTERFACE metric 1024 table stuttgart
service isc-dhcp-relay restart
EOF
chmod +x /etc/tinc/ffsbb/tinc-up
cat <<EOF >/etc/tinc/ffsbb/tinc-down
#!/bin/sh
ip rule del iif \$INTERFACE table stuttgart priority 7000
ip rule del to 10.190.0.0/15 table stuttgart
ip rule del to 172.21.0.0/18 table stuttgart
EOF
chmod +x /etc/tinc/ffsbb/tinc-down
# debug auf 2
cat <<EOF >/etc/default/tinc
# Debuglevel auf 2
EXTRA="-d 2"
EOF
# tinc aktivieren
echo "ffsbb" >>/etc/tinc/nets.boot
}

setup_tinc_key() {
if [ ! -e /etc/tinc/ffsbb/rsa_key.priv ]; then
  echo | tincd -n ffsbb -K 4096
fi
# key verschieben
if [ ! -d /etc/tinc/ffsbb/hosts.1 ]; then
  mv /etc/tinc/ffsbb/hosts /etc/tinc/ffsbb/hosts.1
  ln -s /root/tinc-ffsbb/hosts /etc/tinc/ffsbb/hosts
fi
# hosts Datei anpassen
ensureline "address = $HOSTNAME.freifunk-stuttgart.de" /etc/tinc/ffsbb/hosts.1/$HOSTNAME
ensureline "port = 6551" /etc/tinc/ffsbb/hosts.1/$HOSTNAME
}


setup_tincl3_config() {
if [ ! -d /root/tinc-ffsl3/.git ]; then
  git clone https://github.com/freifunk-stuttgart/tinc /root/tinc-ffsl3
fi
if [ ! -d /etc/tinc/ffsl3 ]; then
    mkdir -p /etc/tinc/ffsl3/hosts
fi
cat <<EOF >/etc/tinc/ffsl3/tinc.conf
Name = $HOSTNAME
#ConnectTo = dhcp01
ConnectTo = dhcp02
ConnectTo = dhcp03
ConnectTo = gw05n01
#ConnectTo = gw08n04
#ConnectTo = gw08n05
Mode = router
Port = 6552
DeviceType = tap
#GraphDumpFile = /tmp/ffsl3.gv
EOF
cat <<EOF >/etc/tinc/ffsl3/tinc-up
#!/bin/sh
ip addr add 10.191.255.$GWID$GWSUBID/24 broadcast 10.191.255.255 dev \$INTERFACE
ip link set \$INTERFACE up
ip rule add iif \$INTERFACE table stuttgart priority 7000
ip route add 10.191.255.0/24 proto kernel scope link src 10.191.255.$GWID$GWSUBID dev \$INTERFACE table stuttgart
ip route add 10.190.0.0/15 dev \$INTERFACE metric 512
ip route add 10.190.0.0/15 dev \$INTERFACE metric 512 table stuttgart
ip addr add fd21:b4dc:4b00::a38:$GWLID$GWLSUBID/128 dev \$INTERFACE
ip route add fd21:b4dc:4b00::/40 dev \$INTERFACE metric 512
ip route add fd21:b4dc:4b00::/40 dev \$INTERFACE metric 512 table stuttgart
service isc-dhcp-relay restart
EOF
chmod +x /etc/tinc/ffsl3/tinc-up
cat <<EOF >/etc/tinc/ffsl3/tinc-down
#!/bin/sh
ip rule del iif \$INTERFACE table stuttgart priority 7000
EOF
chmod +x /etc/tinc/ffsl3/tinc-down
# debug auf 2
cat <<EOF >/etc/default/tinc
# Debuglevel auf 2
EXTRA="-d 2"
EOF
# tinc conf.d einrichten
if [ ! -d /etc/tinc/ffsl3/conf.d ]; then
  ln -s /root/tinc-ffsl3/ffsl3/conf.d /etc/tinc/ffsl3/conf.d
fi
# tinc aktivieren
echo "ffsl3" >>/etc/tinc/nets.boot
}

setup_tincl3_key() {
if [ ! -e /etc/tinc/ffsl3/rsa_key.priv ]; then
  echo | tincd -n ffsl3 -K 4096
fi
# key verschieben
if [ ! -d /etc/tinc/ffsl3/hosts.1 ]; then
  mv /etc/tinc/ffsl3/hosts /etc/tinc/ffsl3/hosts.1
  ln -s /root/tinc-ffsl3/ffsl3/hosts /etc/tinc/ffsl3/hosts
fi
# hosts Datei anpassen
ensureline "address = $HOSTNAME.freifunk-stuttgart.de" /etc/tinc/ffsl3/hosts.1/$HOSTNAME
ensureline "port = 6552" /etc/tinc/ffsl3/hosts.1/$HOSTNAME
# hosts config subnet hinzufuegen
cp -f /etc/tinc/ffsl3/hosts.1/$HOSTNAME /etc/tinc/ffsl3/${HOSTNAME}
cat <<EOF >>/etc/tinc/ffsl3/${HOSTNAME}
subnet = 10.191.255.$GWID$GWSUBID/32
subnet = fd21:b4dc:4b00::a38:$GWLID$GWLSUBID/128
EOF
for seg in $SEGMENTLIST; do
netz=$((${seg#0} - 1))
netz=$(($netz * 8))
cat <<EOF >>/etc/tinc/ffsl3/${HOSTNAME}
subnet = 10.190.$netz.$GWID$GWSUBID/32
subnet = 10.190.$netz.0/21
subnet = fd21:b4dc:4b$seg::a38:$GWLID$GWLSUBID/128
subnet = fd21:b4dc:4b$seg::/64
EOF
done
}

