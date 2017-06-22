setup_dnsmasq() {
rm -f /etc/dnsmasq.d/dns
for seg in $SEGMENTLIST ; do
cat <<EOF >>/etc/dnsmasq.d/dns
interface=br$seg
interface=bat$seg
interface=vpn$seg
EOF
done
cat <<EOF >>/etc/dnsmasq.d/dns
bind-interfaces
log-facility=/var/log/dnsmasq.log

no-resolv
no-hosts
cache-size=4096
#log-queries
# .ffs/ffstg.de Weiterleitung
server=/ffs/10.191.255.41
server=/ffstg.de/51.254.139.175
# Forward DNS requests via wan-vpn
server=85.214.20.141 #@tun0 # FoeBud
server=213.73.91.35 #@tun0  # dnscache.berlin.ccc.de
server=141.1.1.1 #@tun0  #
server=8.8.8.8 #@tun0  # Google
server=8.8.4.4 #@tun0  # Google
EOF

}
