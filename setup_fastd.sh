#!/bin/bash
LOADBALANCER_PATH=/var/lib/ffs/loadbalancer
setup_fastd_loadbalancer() {
  if [ ! -d "$LOADBALANCER_PATH" ]; then
    git clone https://github.com/freifunk-stuttgart/loadbalancer.git "$LOADBALANCER_PATH"
  else
    git -C "$LOADBALANCER_PATH" pull
  fi
  if [ ! -f /etc/cron.d/gw-loadbalancer ]; then
    echo '/var/lib/ffs/loadbalancer/genGwStatus.py -o /var/www/html/data/gwstatus.json -b 1500 -s 33 -i eth0' > /etc/cron.d/gw-loadbalancer
  fi
}
setup_fastd() {
  if ! getent passwd fastd 2>/dev/null 1>&2; then
    adduser --system --no-create-home fastd
  fi

  cat <<'EOF' >/etc/systemd/system/fastd@.service
[Unit]
Description=Fast and Secure Tunnelling Daemon (connection %I)
After=network.target

[Service]
Type=notify
ExecStartPre=/bin/rm -f /var/run/fastd/fastd-%I.sock
ExecStartPre=/bin/mkdir -p /var/run/fastd
ExecStart=/usr/bin/fastd --syslog-level verbose --syslog-ident fastd@%I -c /etc/fastd/%I/fastd.conf
ExecStopPost=/sbin/ifdown %I
ExecReload=/bin/kill -HUP $MAINPID
Restart=always

[Install]
WantedBy=multi-user.target

EOF
}
setup_fastd_config() {
  # Might do separate fastd for ipv4 and ipv6
  group="peers"
  for ipv in ip4 ip6; do
    if [ x$FASTD_SPLIT == x1 ] || [ $ipv == ip4 ]; then
      for seg in $SEGMENTLIST; do
        i=${seg##0}
        if [ $i -eq 0 ]; then
          vpnport=10037
        else
          vpnport=$((10040+$i))
        fi
        if [ $ipv == ip6 ]; then
          dir=/etc/fastd/vpn${seg}ip6
          iface="vpn${seg}ip6"
        else
          dir=/etc/fastd/vpn$seg
          iface="vpn${seg}"
        fi
        mkdir -p $dir
        cat <<-EOF >$dir/fastd.conf
	log to syslog level warn;
	interface "$iface";
	method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
	method "salsa2012+umac";  
	method "null+salsa2012+umac";
	$(if [ x$FASTD_SPLIT == x ] || [ $ipv == ip4 ]; then for a in $EXT_IP_V4; do echo bind $a:$vpnport\;; done; fi)
	$(if [ x$FASTD_SPLIT == x ] || [ $ipv == ip6 ]; then for a in $EXT_IPS_V6; do echo bind [$a]:$vpnport\;; done; fi)
	mtu 1340;
	include "/etc/fastd/secret_vpn.conf";
	status socket "/var/run/fastd/fastd-vpn${seg}$(if [ x$FASTD_SPLIT != x ] && [ $ipv == ip6 ]; then echo -n ip6; fi).sock";
	#peer group "${group}" {
	#    include peers from "/etc/fastd/peers-ffs/vpn${seg}/${group}";
	#}
        on verify "/var/lib/ffs/loadbalancer/fastd-verify.py -k /etc/fastd/peers-ffs/vpn${seg}/peers -g /var/www/html/data/gwstatus.json";
	on up "ifup --force $iface";
	EOF
      done
    fi
  done
  # Low MTU fastd, 1340
  for seg in $SEGMENTLIST; do
    i=${seg##0}
    vpnport=$((10200+$i))
    dir=/etc/fastd/vpy$seg
    iface="vpy${seg}"
    mkdir -p $dir
    cat <<-EOF >$dir/fastd.conf
	log to syslog level warn;
	interface "$iface";
	method "null@l2tp";
	method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
	method "salsa2012+umac";  
	method "null+salsa2012+umac";
	$(for a in $EXT_IP_V4; do echo bind $a:$vpnport\;; done)
	$(for a in $EXT_IPS_V6; do echo bind [$a]:$vpnport\;; done)
	mtu 1340; # Lowest possible MTU
	include "/etc/fastd/secret_vpn.conf";
	status socket "/var/run/fastd/fastd-vpy${seg}.sock";
	#peer group "${group}" {
	#    include peers from "/etc/fastd/peers-ffs/vpn${seg}/${group}";
	#}
        on verify "/var/lib/ffs/loadbalancer/fastd-verify.py -k /etc/fastd/peers-ffs/vpn${seg}/peers -g /var/www/html/data/gwstatus.json";
	on up "ifup --force $iface";
	EOF
  done
}
setup_fastd_bb() {
  mkdir -p /etc/fastd
  group=bb
  if [ ! -e /etc/fastd/secret_vpnbb.key ]; then
    VPNBBKEY=$(fastd --generate-key --machine-readable)
    printf 'secret "%s";' $VPNBBKEY > /etc/fastd/secret_vpnbb.key
  else
    VPNBBKEY=$(sed -n '/secret/{ s/.* "//; s/".*//; p}' /etc/fastd/secret_vpnbb.key)
  fi
  for seg in $SEGMENTLIST; do
    segnum=$(sed 's/\b //' <<< $seg)
    segnum=${segnum##0}
    vpnport=$((9000+$segnum))
    mkdir -p /etc/fastd/bb${seg}
    cat <<-EOF >/etc/fastd/bb${seg}/fastd.conf
	log to syslog level warn;
	interface "bb${seg}";
	method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
	method "salsa2012+umac";  
	method "null+salsa2012+umac";
	$(for a in $EXT_IP_V4; do echo bind $a:$vpnport\;; done)
	$(for a in $EXT_IPS_V6; do echo bind [$a]:$vpnport\;; done)
	include "/etc/fastd/secret_vpnbb.key";
	mtu 1340;
	status socket "/var/run/fastd/fastd-bb${seg}.sock";
	peer group "${group}" {
	    include peers from "/etc/fastd/peers-ffs/vpn${seg}/${group}";
	}
	on up "ifup --force bb${seg}";
EOF
    VPNBBPUB=$(fastd -c /etc/fastd/bb${seg}/fastd.conf --show-key --machine-readable)
    if [ ! -e $FFSGIT/peers-ffs/vpn$seg/$group/$HOSTNAME ] || ! grep $VPNBBPUB $FFSGIT/peers-ffs/vpn$seg/$group/$HOSTNAME; then
      cat <<-EOF >$FFSGIT/peers-ffs/vpn$seg/$group/${HOSTNAME}s$seg
	key "$VPNBBPUB";
	remote "${HOSTNAME}.gw.freifunk-stuttgart.de" port $(printf '9%03i' $segnum);
EOF
    fi
    if [ $NOPUBLICIP -eq 1 ]; then
      sed -i '/^remote/d' $FFSGIT/peers-ffs/vpn$seg/$group/${HOSTNAME}s$seg
    fi
  done
  (
    cd $FFSGIT/peers-ffs
    if LC_ALL=C git status | egrep -q "($HOSTNAME|ahead)"; then
      git add .
      git commit -m "$group $HOSTNAME" -a
      git remote set-url origin git@github.com:freifunk-stuttgart/peers-ffs.git https://github.com/freifunk-stuttgart/peers-ffs
      git push
      git remote set-url origin https://github.com/freifunk-stuttgart/peers-ffs git@github.com:freifunk-stuttgart/peers-ffs.git
    fi
  )
}
setup_fastd_key() {
  if [ ! -e /etc/fastd/peers-ffs ]; then
    ln -s $FFSGIT/peers-ffs /etc/fastd/peers-ffs
  fi
  if [ "$VPNKEY" == "Wird generiert" ] && [ ! -e /etc/fastd/secret_vpn.conf ]; then
    VPNKEY=$(fastd --generate-key --machine-readable)
    cat <<-EOF >/etc/fastd/secret_vpn.conf
	secret "$VPNKEY";
	EOF
  elif [ "$VPNKEY" != "Wird generiert" ]; then
    cat <<-EOF >/etc/fastd/secret_vpn.conf
	secret "$VPNKEY";
	EOF
  else
    VPNKEY=$(sed -n '/secret/{ s/.* "//; s/".*//; p}' /etc/fastd/secret_vpn.conf)
  fi
}
setup_fastd_update() {
  wget https://raw.githubusercontent.com/poldy79/FfsScripts/master/update_peers.py -nd -O /usr/local/bin/update_peers.py
  chmod +x /usr/local/bin/update_peers.py
  wget https://raw.githubusercontent.com/poldy79/FfsScripts/master/fastd-status.py -nd -O /usr/local/bin/fastd-status.py
  chmod +x /usr/local/bin/fastd-status.py
}
