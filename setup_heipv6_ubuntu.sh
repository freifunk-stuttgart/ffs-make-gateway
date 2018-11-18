setup_heipv6_config() {

DATEIHE="/usr/local/bin/heipv6"
if [ -f $DATEIHE ]; then
  HE_GW_V4=$(head -5 $DATEIHE | grep HE_GW_V4= | cut -d '=' -f2)
  HE_IF_V6=$(head -5 $DATEIHE | grep HE_IF_V6= | cut -d '=' -f2)
  HE_IP_V6=$(head -5 $DATEIHE | grep HE_IP_V6= | cut -d '=' -f2)
  HE_IPS_V6=$(head -5 $DATEIHE | grep HE_IPS_V6= | cut -d '=' -f2)
fi
test -z $HE_GW_V4  && HE_GW_V4="1.2.3.4"
test -z $HE_IF_V6  && HE_IF_V6="he-ipv6"
test -z $HE_IP_V6  && HE_IP_V6="1:2:3:4::2/64"
test -z $HE_IPS_V6 && HE_IPS_V6="5:6:7::/48"

HE_IPS_V6_PRE=$(echo "$HE_IPS_V6" | cut -d ':' -f1-3)

#HE_GW_V4=216.66.84.46
#HE_IF_V6=he-ipv6
#HE_IP_V6=2001:470:1f14:bc4::2/64
#HE_IPS_V6=2001:470:7cf4::/48

cat <<EOF >/usr/local/bin/heipv6
#!/bin/bash
HE_GW_V4=$HE_GW_V4
HE_IF_V6=$HE_IF_V6
HE_IP_V6=$HE_IP_V6
HE_IPS_V6=$HE_IPS_V6

modprobe ipv6
HE_IPS_V6_PRE=$HE_IPS_V6_PRE

# alte tunnel loeschen
for seg in $SEGMENTLIST ; do
  ip route del \${HE_IPS_V6_PRE}:4b\${seg}::/64 dev br\$seg
  ip route del \${HE_IPS_V6_PRE}:4b\${seg}::/64 dev br\$seg table stuttgart
done
ip addr del $HE_IP_V6 dev $HE_IF_V6
ip tunnel del $HE_IF_V6 mode sit remote $HE_GW_V4 local $EXT_IP_V4 ttl 255

sleep 10

# neuer tunnel aufbauen
ip tunnel add $HE_IF_V6 mode sit remote $HE_GW_V4 local $EXT_IP_V4 ttl 255
ip link set $HE_IF_V6 up
ip addr add $HE_IP_V6 dev $HE_IF_V6
ip route add ::/0 dev $HE_IF_V6
ip -f inet6 addr dev $HE_IF_V6

# zusatzrouten
for seg in $SEGMENTLIST ; do
  ip route add \${HE_IPS_V6_PRE}:4b\${seg}::/64 dev br\$seg
  ip route add \${HE_IPS_V6_PRE}:4b\${seg}::/64 dev br\$seg table stuttgart
done
EOF
chmod +x $DATEIHE
}

