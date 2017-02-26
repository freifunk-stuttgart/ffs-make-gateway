setup_fastd_config() {
if [ ! -d /etc/fastd/peers/.git ]; then
  git clone https://github.com/freifunk-stuttgart/peers-ffs /etc/fastd/peers
else
  ( cd /etc/fastd/peers && git pull )
fi
# BB key generieren
if [ ! -e /etc/fastd/gateway-bb.key ]; then
  fastd --generate-key > /etc/fastd/gateway-bb.key
fi
if [ ! -e /etc/fastd/secret-bb.key ]; then
cat <<-EOF >/etc/fastd/secret-bb.conf
secret "$(cat /etc/fastd/gateway-bb.key | grep "Secret" | cut -d" " -f2)";
EOF
fi
# bb public key
keybbpublic=$(cat /etc/fastd/gateway-bb.key | grep "Public" | cut -d" " -f2)
cat <<-EOF >/etc/fastd/$HOSTNAME
#MAC: 02:00:38:$SEGMENT1:$GWLID:$GWLSUBID
key "$(cat /etc/fastd/gateway-bb.key | grep "Public" | cut -d" " -f2)";
remote "$HOSTNAME.freifunk-stuttgart.de" port $((9040 + $SEGMENT1));
EOF
# gatewaykey
if [ "$VPNKEY" != "Wird generiert" ]; then
  cat <<EOF >/etc/fastd/secret.conf
secret "$VPNKEY";
EOF
fi

# alte Verzeichnisse und Dateien löschen
rm -rf /etc/fastd/bb[0-6][0-9]
rm -rf /etc/fastd/vpn[0-6][0-9]
rm -rf /etc/fastd/vpn[0-6][0-9]bb
rm /etc/fastd/${HOSTNAME}s[0-6][0-9]

# fastd Verzeichnisse anlegen
for seg in $SEGMENTLIST; do
    vpnport=$((10040 + ${seg#0}))
    vpnportbb=$((9040 + ${seg#0}))
    dir=/etc/fastd/vpn$seg
    dirbb=/etc/fastd/bb$seg
    iface="vpn${seg}"
    ifacebb="bb${seg}"
    mkdir -p $dir
    mkdir -p $dirbb
    if [ ! -d $dir/peers ]; then
      ln -s /etc/fastd/peers/$iface/peers $dir/peers
    fi
    if [ ! -d $dirbb/bb ]; then
      ln -s /etc/fastd/peers/$iface/bb $dirbb/bb
    fi
    # ip6 pruefen
    if [ -z "$EXT_IPS_V6" ]; then
	i="#"
    else
	i=""
    fi
# fastd bb config fuer git
cat <<-EOF >/etc/fastd/${HOSTNAME}s$seg
#MAC: 02:00:38:$seg:$GWLID:$GWLSUBID
key "$keybbpublic";
remote "$HOSTNAME.freifunk-stuttgart.de" port $vpnportbb;
EOF
cat <<-EOF >$dir/fastd.conf
interface "$iface";
status socket "/var/run/fastd-$iface.status";
bind $EXT_IP_V4:$vpnport;
${i}bind [$EXT_IPS_V6]:$vpnport;
include "../secret.conf";
include peers from "peers";
# error|warn|info|verbose|debug|debug2
log level info;
hide ip addresses yes;
hide mac addresses yes;
method "salsa2012+umac";    # new method (faster)
method "salsa2012+gmac";
#method "null+salsa2012+umac";
mtu 1406; # 1492 - IPv4/IPv6 Header - fastd Header...
#peer limit 60;
EOF

    cat <<-EOF >$dirbb/fastd.conf
interface "$ifacebb";
status socket "/var/run/fastd-$ifacebb.status";
bind $EXT_IP_V4:$vpnportbb;
${i}bind [$EXT_IPS_V6]:$vpnportbb;
include "../secret-bb.conf";
include peers from "bb";
# error|warn|info|verbose|debug|debug2
log level info;
hide ip addresses yes;
hide mac addresses yes;
method "salsa2012+umac";    # new method (faster)
method "salsa2012+gmac";
#method "null+salsa2012+umac";
mtu 1406; # 1492 - IPv4/IPv6 Header - fastd Header...
#peer limit 60;
EOF
done
}
