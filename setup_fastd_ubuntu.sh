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
else
  VPNKEY=$(sed -n '/secret/{ s/.* "//; s/".*//; p}' /etc/fastd/secret.conf)
fi

# Might do separate fastd for ipv4 and ipv6
  for seg in $SEGMENTLIST; do
    VPNPORT=$((10040 + ${seg#0}))
    VPNPORTBB=$((9040 + ${seg#0}))
    dir=/etc/fastd/vpn$seg
    dirbb=${dir}bb
    iface="vpn${seg}"
    ifacebb=${iface}bb
    mkdir -p $dir
    mkdir -p $dirbb
    if [ ! -d $dir/peers ]; then
      ln -s /etc/fastd/peers/$iface/peers $dir/peers
    fi
    if [ ! -d $dirbb/bb ]; then
      ln -s /etc/fastd/peers/$iface/bb $dirbb/bb
    fi
    cat <<-EOF >$dir/fastd.conf
interface "$iface";
status socket "/var/run/fastd-$iface.status";
bind $EXT_IP_V4:$VPNPORT;
#bind $EXT_IP_V6:$VPNPORT;
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
bind $EXT_IP_V4:$VPNPORTBB;
#bind $EXT_IP_V6:$VPNPORTBB;
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
