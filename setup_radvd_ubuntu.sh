setup_radvd() {
rm -f /etc/radvd.conf
for seg in $SEGMENTLIST ; do
cat <<EOF >>/etc/radvd.conf
interface br$seg
{
  AdvSendAdvert on;
  IgnoreIfMissing on;
  MinRtrAdvInterval 60;
  MaxRtrAdvInterval 300;
  MinDelayBetweenRAs 30;
  prefix fd21:b4dc:4b$seg::/64 {};
  RDNSS fd21:b4dc:4b$seg::a38:$GWLID$GWLSUBID {};
  route fd21:b4dc:4b00::/40 {};
  prefix $IP6$(printf %02x $seg)/64
  {
      AdvOnLink on;
      AdvAutonomous on;
      AdvRouterAddr on;
      AdvValidLifetime 7200;
      AdvPreferredLifetime 300;
  };

#    prefix ${HE_IPS_V6_PRE}:4b${seg}::/64
#    {
#    AdvOnLink on;
#    AdvAutonomous on;
#    AdvRouterAddr on;
#    };
};

EOF
done
}
