has_segment_ip6() {
	seg=$1

	if [ -z $IP6 ]; then
		return 1
	fi

	if [ -z $IP6_SEGMENTS ]; then
		return 0
	fi

	if [[ $IP6_SEGMENTS =~ ^([0-9]+,)*"$seg"(,[0-9]*)$ ]]; then
		return 0
	fi

	return 1
}

setup_radvd() {
rm -f /etc/radvd.conf
for seg in $SEGMENTLIST ; do
seghex=$(printf %02x ${seg#0})
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
  # global gateway-independant IPs
  prefix 2a03:2260:3016:$seghex::/64
  {
      AdvValidLifetime 300;
      AdvPreferredLifetime 0;
  };
  prefix 2a01:1e8:c003:$seghex::/64
  {
      AdvValidLifetime 300;
      AdvPreferredLifetime 0;
  };

EOF
if has_segment_ip6 $seg; then
	cat <<-EOF >> /etc/radvd.conf
	  prefix $IP6$seghex::/64
	  {
	      AdvOnLink on;
	      AdvAutonomous on;
	      AdvRouterAddr on;
	      AdvValidLifetime 7200;
	      AdvPreferredLifetime 300;
	  };
EOF
else
	echo "  AdvDefaultLifetime 0;" >> /etc/radvd.conf
fi

cat <<-EOF >> /etc/radvd.conf
};
EOF
done
}
