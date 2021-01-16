setup_backbone() {
  cat <<-EOF >/etc/network/interfaces.d/ffsbblo
	auto ffsbblo
	iface ffsbblo inet static
	  address 10.191.255.$(($GWID*10+$GWSUBID))/32
	  #up ip addr add 10.191.254.$(($GWID*10+$GWSUBID))/32 dev \$IFACE || true
          up ip addr add fd21:b4dc:4b00::a38:$(printf '%i%02i' $GWID $GWSUBID)/128 dev \$IFACE || true
          pre-up /sbin/ip link add \$IFACE type dummy
          pre-down /sbin/ip link delete \$IFACE
EOF
}
