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
ConnectTo = gw01n03
ConnectTo = gw05n02
ConnectTo = gw08n02
ConnectTo = gw08n03
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
ip route add 10.190.0.0/15 dev \$INTERFACE
ip route add 10.190.0.0/15 dev \$INTERFACE table stuttgart
ip addr add fd21:b4dc:4b00::a38:$GWLID$GWLSUBID/64 dev \$INTERFACE
ip route add fd21:b4dc:4b00::/40 dev \$INTERFACE
ip route add fd21:b4dc:4b00::/40 dev \$INTERFACE table stuttgart
service isc-dhcp-server restart
EOF
chmod +x /etc/tinc/ffsbb/tinc-up
cat <<EOF >/etc/tinc/ffsbb/tinc-down
#!/bin/sh
ip rule del iif \$INTERFACE table stuttgart priority 7000
ip rule del to 10.190.0.0/15 table stuttgart
ip rule del to 172.21.0.0/18 table stuttgart
EOF
chmod +x /etc/tinc/ffsbb/tinc-down
# hosts Datei anpassen nur einmal
if [ ! -e /etc/tinc/ffsbb/rsa_key.priv ]; then
  ensureline "address = $HOSTNAME.freifunk-stuttgart.de" /etc/tinc/ffsbb/hosts/$HOSTNAME
  ensureline "port = 6551" /etc/tinc/ffsbb/hosts/$HOSTNAME
fi
# debug auf 2
cat <<EOF >/etc/default/tinc
# Debuglevel auf 2
EXTRA="-d 2"
EOF
# tinc aktivieren
ensureline "ffsbb" /etc/tinc/nets.boot
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
}

