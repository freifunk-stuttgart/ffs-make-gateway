setup_radvd() {
for seg in $SEGMENTLIST ; do
cat <<EOF >/etc/radvd.conf
interface br$seg
{
  AdvSendAdvert on;
  IgnoreIfMissing on;
  MinRtrAdvInterval 60;
  MaxRtrAdvInterval 300;
  MinDelayBetweenRAs 30;
  AdvDefaultLifetime 0;
  prefix fd21:b4dc:4b$seg::/64 {};
  RDNSS fd21:b4dc:4b$seg::a38:$GWID$GWSUBID {};
  route fd21:b4dc:4b00::/40 {};\n"

EOF
done

}
