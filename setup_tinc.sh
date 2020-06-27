setup_tinc_base() {
  mkdir -p /var/lib/ffs/git
  if [ ! -e /etc/systemd/system/tincd\@.service ]; then
    cat <<-'EOF' >/etc/systemd/system/tincd\@.service
	[Unit]
	Description=tincd (connection %I)
	After=network.target

	[Service]
	Type=simple
	ExecStart=/usr/sbin/tincd -n %I -D
	Restart=always

	[Install]
	WantedBy=multi-user.target
	EOF
    systemctl daemon-reload
  fi
  if [ ! -d /var/lib/ffs/git/tinc ]; then
    git clone https://github.com/freifunk-stuttgart/tinc.git /var/lib/ffs/git/tinc
  else
    ( cd /var/lib/ffs/git/tinc && git pull )
  fi
  for tinc in $TINCNETS; do
    mkdir -p /etc/tinc/$tinc
    for ref_file in tinc.conf.sample subnet-up.sample subnet-down.sample conf.d hosts; do
      dst_file=${ref_file%.sample}
      if [ ! -e /etc/tinc/ffsl3/$dst_file ]; then
        ln -s $TINCBASE/tinc/$tinc/$ref_file /etc/tinc/$tinc/$dst_file
      fi
    done
    if [ ! -e /etc/tinc/$tinc/rsa_key.priv ]; then
      ln -s /etc/tinc/rsa_key.priv /etc/tinc/$tinc/
    fi
    systemctl enable tincd@$tinc.service
  done
  if [ x$TINC_FFSBB = x1 ]; then
    if [ ! -d /var/lib/ffs/git/tinc-ffsbb ]; then
      git clone https://github.com/freifunk-stuttgart/tinc-ffsbb /var/lib/ffs/git/tinc-ffsbb
    else
      ( cd /var/lib/ffs/git/tinc-ffsbb && git pull )
    fi
    mkdir -p /etc/tinc/ffsbb
    if [ ! -e /etc/tinc/ffsbb/tinc.conf ]; then
      ln -s $TINCBASE/tinc-ffsbb/tinc.conf.sample /etc/tinc/ffsbb/tinc.conf
    fi
    if [ ! -e /etc/tinc/ffsbb/subnet-up ]; then
      ln -s $TINCBASE/tinc-ffsbb/subnet-up.sample /etc/tinc/ffsbb/subnet-up
    fi
    if [ ! -e /etc/tinc/ffsbb/subnet-down ]; then
      ln -s $TINCBASE/tinc-ffsbb/subnet-down.sample /etc/tinc/ffsbb/subnet-down
    fi
    if [ ! -e /etc/tinc/ffsbb/subnet-down ]; then
      ln -s $TINCBASE/tinc-ffsbb/conf.d /etc/tinc/ffsbb/conf.d
    fi
    if [ ! -e /etc/tinc/ffsbb/hosts ]; then
      ln -s $TINCBASE/tinc-ffsbb/hosts /etc/tinc/ffsbb/hosts
    fi
    systemctl enable tincd@ffsbb.service
  fi
}
setup_tinc_config() {
  for tinc in $TINCNETS; do
    cat <<-EOF >/etc/tinc/$tinc/hosts/$HOSTNAME
	Digest = sha256
	Address = $HOSTNAME.gw.freifunk-stuttgart.de
	Port = 110$GWID$GWSUBID
	EOF
    for segment in $SEGMENTLIST; do
      IPv4seg=$((${segment#0} * 8 - 8))
      if [ $IPv4seg -gt 255 ]; then
        IPv4seg=$(($IPv4seg-256))
        IPv4segbase=191
      else
        IPv4segbase=190
      fi
      cat <<-EOF >>/etc/tinc/$tinc/hosts/$HOSTNAME
	Subnet = 10.$IPv4segbase.$IPv4seg.$GWID$GWSUBID
	Subnet = 10.$IPv4segbase.$IPv4seg.0/21
	Subnet = fd21:b4dc:4b$segment::/64
	Subnet = fd21:b4dc:4b$segment::a38:$(printf '%i%02i' $GWID $GWSUBID)
	EOF
    done
    cat <<-EOF >>/etc/tinc/$tinc/hosts/$HOSTNAME
	Subnet = 10.191.254.$GWID$GWSUBID
	Subnet = 10.191.255.$GWID$GWSUBID
	Subnet = fd21:b4dc:4b00::a38:$(printf '%i%02i' $GWID $GWSUBID)
	EOF
    cat /etc/tinc/rsa_key.pub >>/etc/tinc/$tinc/hosts/$HOSTNAME
    cat <<-EOF >/etc/tinc/$tinc/conf.d/$HOSTNAME
	ConnectTo = $HOSTNAME
	EOF
  done
  (
    cd $FFSGIT/tinc
    if LC_ALL=C git status | egrep -q "($HOSTNAME|ahead)"; then
      git add . || true
      git commit -m "add/update $HOSTNAME" -a || true
      git remote set-url origin git@github.com:freifunk-stuttgart/tinc.git
      git push
      git remote set-url origin https://github.com/freifunk-stuttgart/tinc
    fi
  )
  if [ x$TINC_FFSBB = x1 ]; then
    ensureline "PMTUDiscovery = yes" /etc/tinc/ffsbb/hosts/$HOSTNAME
    ensureline "Digest = sha256" /etc/tinc/ffsbb/hosts/$HOSTNAME
    ensureline "ClampMSS = yes" /etc/tinc/ffsbb/hosts/$HOSTNAME
    ensureline "Address = $HOSTNAME.freifunk-stuttgart.de" /etc/tinc/ffsbb/hosts/$HOSTNAME
    ensureline "Port = 119${GWLID}" /etc/tinc/ffsbb/hosts/$HOSTNAME
    ensureline "ConnectTo = $HOSTNAME" /etc/tinc/ffsbb/tinc.conf.sample
    if [ ! -e /etc/tinc/ffsbb/conf.d/$HOSTNAME ]; then
      echo ConnectTo = $HOSTNAME > /etc/tinc/ffsbb/conf.d/$HOSTNAME
      ( cd $TINCBASE/ffsbb && git add conf.d/$HOSTNAME )
    fi
    (
      cd $TINCNETS/tinc-ffsbb
      if LC_ALL=C git status | egrep -q "($HOSTNAME|ahead)"; then
        git add . || true
        git commit -m "add/update $HOSTNAME" -a || true
        git remote set-url origin git@github.com:freifunk-stuttgart/tinc-ffsbb.git
        git push
        git remote set-url origin https://github.com/freifunk-stuttgart/tinc-ffsbb
      fi
    )
  fi
}
setup_tinc_key() {
  if [ ! -e /etc/tinc/rsa_key.priv ]; then
    echo | tincd -K 4096
  fi
  if [ x$TINC_FFSBB = x1 ]; then
    if [ ! -e /etc/tinc/ffsbb/rsa_key.priv ]; then
      ln -s /etc/tinc/rsa_key.priv /etc/tinc/ffsbb/
    fi
    if ! grep -q "BEGIN RSA PUBLIC KEY" /etc/tinc/ffsbb/hosts/$HOSTNAME; then
      cat </etc/tinc/rsa_key.pub >> /etc/tinc/ffsbb/hosts/$HOSTNAME
    fi
  fi
}
setup_tinc_interface() {
  if [ x$TINC_FFSBB = x1 ]; then
    cat <<-EOF >/etc/network/interfaces.d/ffsbb
	allow-hotplug ffsbb
	iface ffsbb inet static
	    address 10.191.255.$(($GWID*10+$GWSUBID))
	    netmask 255.255.255.0
	    broadcast 10.191.255.255
	    mtu 1280
	    post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000 || true
	    post-up         /sbin/ip rule add iif \$IFACE table ffsdefault priority 10000 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table ffsdefault priority 10000 || true
	    post-up         /sbin/ip rule add iif \$IFACE table nodefault priority 10001 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table nodefault priority 10001 || true
	    post-up         /sbin/ip route add 10.191.255.0/24 dev \$IFACE table stuttgart || true
	    post-down       /sbin/ip route del 10.191.255.0/24 dev \$IFACE table stuttgart || true

	iface ffsbb inet6 static
	    address fd21:b4dc:4b00::a38:$(printf '%i%02i' $GWID $GWSUBID)
	    post-up         /sbin/ip r a fd21:b4dc:4b00::/64 table stuttgart dev ffsbb ||true
	    pre-down        /sbin/ip r d fd21:b4dc:4b00::/64 table stuttgart dev ffsbb ||true
	    netmask 64

	EOF
    cat <<-EOF >/etc/network/interfaces.d/ffsl3
	allow-hotplug ffsl3
	iface ffsbb inet static
	    address 10.191.254.$(($GWID*10+$GWSUBID))
	    netmask 255.255.255.0
	    broadcast 10.191.254.255
	    mtu 1280
	    post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000 || true
	    post-up         /sbin/ip rule add iif \$IFACE table ffsdefault priority 10000 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table ffsdefault priority 10000 || true
	    post-up         /sbin/ip rule add iif \$IFACE table nodefault priority 10001 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table nodefault priority 10001 || true
	    post-up         /sbin/ip route add 10.191.254.0/24 dev \$IFACE table stuttgart || true
	    post-down       /sbin/ip route del 10.191.254.0/24 dev \$IFACE table stuttgart || true

	EOF
  else
    cat <<-EOF >/etc/network/interfaces.d/ffsl3
	allow-hotplug ffsl3
	iface ffsl3 inet static
	    address 10.191.254.$(($GWID*10+$GWSUBID))
	    netmask 255.255.255.0
	    broadcast 10.191.254.255
	    mtu 1280
	    post-up         /sbin/ip addr add 10.191.255.$(($GWID*10+$GWSUBID)) dev \$IFACE || true
	    post-up         /sbin/ip rule add iif \$IFACE table stuttgart priority 7000 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table stuttgart priority 7000 || true
	    post-up         /sbin/ip rule add iif \$IFACE table ffsdefault priority 10000 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table ffsdefault priority 10000 || true
	    post-up         /sbin/ip rule add iif \$IFACE table nodefault priority 10001 || true
	    pre-down        /sbin/ip rule del iif \$IFACE table nodefault priority 10001 || true
	    post-up         /sbin/ip route add 10.191.254.0/24 dev \$IFACE table stuttgart || true
	    post-down       /sbin/ip route del 10.191.254.0/24 dev \$IFACE table stuttgart || true

	iface ffsl3 inet6 static
	    address fd21:b4dc:4b00::a38:$(printf '%i%02i' $GWID $GWSUBID)
	    post-up         /sbin/ip r a fd21:b4dc:4b00::/64 table stuttgart dev ffsbb ||true
	    pre-down        /sbin/ip r d fd21:b4dc:4b00::/64 table stuttgart dev ffsbb ||true
	    netmask 64

	EOF
  fi
}
setup_tinc_update() {
  cat <<-EOF >/usr/local/bin/tinc_update.sh
	LC_ALL=C
	if [ x$TINC_FFSBB = x1 ]; then
	  cd $TINCBASE/ffsbb
	  if ! git pull 2>&1 | grep 'Already up-to-date' >/dev/null; then
	    systemctl reload tinc@ffsbb
	  fi
	fi
	for tinc in $TINCNETS; do
	cd $TINCBASE/\$tinc
	if ! git pull 2>&1 | grep 'Already up-to-date' >/dev/null; then
	  systemctl reload tinc@\$tinc
	fi
	EOF
  chmod +x /usr/local/bin/tinc_update.sh
}
