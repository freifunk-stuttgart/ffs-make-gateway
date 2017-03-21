setup_iscdhcprelay_config() {
# default config neu schreiben
cat <<-EOF >/etc/default/isc-dhcp-relay
# geschrieben von ffs-make-gateway-ubuntu
SERVERS="10.191.255.251 10.191.255.252 10.191.255.253"

# On what interfaces should the DHCP relay (dhrelay) serve DHCP requests?
INTERFACES="ffsbb$(echo " $SEGMENTLIST" | sed 's/ / br/g')"

# Additional options that are passed to the DHCP relay daemon?
OPTIONS=""
EOF
}


setup_iscdhcpserver_config() {
start=$(($DHCPID * 4 ))
stop=$(($start + 3 ))

cat <<-EOF >/etc/dhcp/dhcpd.conf
ddns-update-style none;

default-lease-time 300;
max-lease-time 300;
ping-check false;

#log-facility local7;
log-facility local6;
option space freifunk;
option freifunk-encapsulation code 82 = encapsulate freifunk;
option freifunk.server-id code 11 = { unsigned integer 8, unsigned integer 8, unsigned integer 8, unsigned integer 8, unsigned integer 8 };

#option ntp-servers 10.191.255.81, 10.191.255.82, 10.191.255.52;
authoritative;
if (packet(24, 4) != 00:00:00:00) {
    option routers = packet(24, 4);
    option freifunk.server-id = packet(24, 4);
    option domain-name-servers = packet(24, 4);
    option dhcp-server-identifier = packet(24, 4);
    option ntp-servers = packet(24, 4);
}

subnet 10.191.255.0 netmask 255.255.255.0 {}
EOF

cat <<-EOF >>/etc/dhcp/dhcpd.conf
subnet 172.21.0.0 netmask 255.255.192.0 { pool { range 172.21.28.11 172.21.31.254; allow all clients; } }
EOF

for seg in $SEGMENTLIST ; do
netz=$((${seg#0} - 1))
netz=$(($netz * 8))
start=$(($DHCPID * 2 + $netz ))
stop=$(($start + 1 ))
cat <<-EOF >>/etc/dhcp/dhcpd.conf
subnet 10.190.$netz.0 netmask 255.255.248.0 { pool { range 10.190.$start.0 10.190.$stop.254; allow all clients; } }
EOF
done

}
