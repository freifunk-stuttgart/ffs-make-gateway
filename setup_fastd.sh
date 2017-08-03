#!/bin/bash
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
ExecStartPre=/bin/mkdir -p /var/run/fastd
ExecStartPre=/bin/chown fastd /var/run/fastd
ExecStartPre=/bin/rm -f /var/run/fastd/fastd-%I.sock
ExecStart=/usr/bin/fastd --syslog-level debug2 --syslog-ident fastd@%I -c /etc/fastd/%I/fastd.conf --pid-file /var/run/fastd/fastd-%I.pid --status-socket /var/run/fastd/fastd-%I.sock --user fastd
ExecStop=/bin/kill $(cat /var/run/fastd/fastd-%I.pid)
ExecReload=/bin/kill -HUP $(cat /var/run/fastd/fastd-%I.pid)
ExecStop=/bin/kill $(cat /var/run/fastd/fastd-%I.pid)

[Install]
WantedBy=multi-user.target
EOF
}
setup_fastd_config() {
  # Might do separate fastd for ipv4 and ipv6
  group="peers"
  segext=""
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
          dir=/etc/fastd/vpn${seg}${segext}ip6
          iface="vpn${seg}${segext}ip6"
        else
          dir=/etc/fastd/vpn$seg${segext}
          iface="vpn${seg}${segext}"
        fi
        mkdir -p $dir
        cat <<-EOF >$dir/fastd.conf
	log to syslog level warn;
	interface "$iface";
	method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
	method "salsa2012+umac";  
	$(if [ x$FASTD_SPLIT == x ] || [ $ipv == ip4 ]; then for a in $EXT_IP_V4; do echo bind $a:$vpnport\;; done; fi)
	$(if [ x$FASTD_SPLIT == x ] || [ $ipv == ip6 ]; then for a in $EXT_IPS_V6; do echo bind [$a]:$vpnport\;; done; fi)
	log to syslog level warn;
	mtu 1406; # 1492 - IPv4/IPv6 Header - fastd Header...
	include "/etc/fastd/secret_vpn${segext}.conf";
	on verify "/root/freifunk/unclaimed.py";
	status socket "/var/run/fastd/fastd-vpn${seg}${segext}$(if [ x$FASTD_SPLIT != x ] && [ $ipv == ip6 ]; then echo -n ip6; fi).sock";
	peer group "${group}" {
	    include peers from "/etc/fastd/peers-ffs/vpn${seg}/${group}";
	}
	EOF
      done
    fi
  done
  # Low MTU fastd
  segext=mtu
  for seg in $SEGMENTLIST; do
    i=${seg##0}
    vpnport=$((10000+$i))
    dir=/etc/fastd/vpn$seg${segext}
    iface="vpn${seg}${segext}"
    mkdir -p $dir
    cat <<-EOF >$dir/fastd.conf
	log to syslog level warn;
	interface "$iface";
	method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
	method "salsa2012+umac";  
	$(for a in $EXT_IP_V4; do echo bind $a:$vpnport\;; done)
	$(for a in $EXT_IPS_V6; do echo bind [$a]:$vpnport\;; done)
	log to syslog level warn;
	mtu 1312; # Lowest possible MTU
	include "/etc/fastd/secret_vpn.conf";
	on verify "/root/freifunk/unclaimed.py";
	status socket "/var/run/fastd/fastd-vpn${seg}${segext}.sock";
	peer group "${group}" {
	  include peers from "/etc/fastd/peers-ffs/vpn${seg}/${group}";
	}
	EOF
  done
}
setup_fastd_bb() {
  mkdir -p /etc/fastd
  group=bb
  segext=bb
  if [ ! -e /etc/fastd/secret_vpn${segext}.key ]; then
    VPNBBKEY=$(fastd --generate-key --machine-readable)
    printf 'secret "%s";' $VPNBBKEY > /etc/fastd/secret_vpn${segext}.key
  else
    VPNBBKEY=$(sed -n '/secret/{ s/.* "//; s/".*//; p}' /etc/fastd/secret_vpn${segext}.key)
  fi
  for seg in $SEGMENTLIST; do
    segnum=$(sed 's/\b //' <<< $seg)
    segnum=${segnum##0}
    vpnport=$((9000+$segnum))
    mkdir -p /etc/fastd/vpn${seg}$segext
    cat <<-EOF >/etc/fastd/vpn${seg}${segext}/fastd.conf
	log to syslog level warn;
	interface "vpn${seg}${segext}";
	method "salsa2012+gmac";    # new method, between gateways for the moment (faster)
	method "salsa2012+umac";  
	$(for a in $EXT_IP_V4; do echo bind $a:$vpnport\;; done)
	$(for a in $EXT_IPS_V6; do echo bind [$a]:$vpnport\;; done)
	include "/etc/fastd/secret_vpn${segext}.key";
	mtu 1406; # 1492 - IPv4/IPv6 Header - fastd Header...
	on verify "/root/freifunk/unclaimed.py";
	status socket "/var/run/fastd/fastd-vpn${seg}${segext}.sock";
	peer group "${group}" {
	    include peers from "/etc/fastd/peers-ffs/vpn${seg}/${group}";
	}
EOF
    VPNBBPUB=$(fastd -c /etc/fastd/vpn${seg}${segext}/fastd.conf --show-key --machine-readable)
    if [ ! -e $FFSGIT/peers-ffs/vpn$seg/$group/$HOSTNAME ] || ! grep $VPNBBPUB $FFSGIT/peers-ffs/vpn$seg/$group/$HOSTNAME; then
      cat <<-EOF >$FFSGIT/peers-ffs/vpn$seg/$group/${HOSTNAME}s$seg
	key "$VPNBBPUB";
	remote "${HOSTNAME}.freifunk-stuttgart.de" port $(printf '9%03i' $segnum);
EOF
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
  if [ ! -e /usr/local/bin/update_peers.py ]; then
    wget https://raw.githubusercontent.com/poldy79/FfsScripts/master/update_peers.py -nd -P /usr/local/bin/
    chmod +x /usr/local/bin/update_peers.py
  fi
  cat <<-'EOF' >/usr/local/bin/fastd-status
	VPNS=\$(ls /var/run/fastd/fastd-*sock | sed 's/^.*\///; s/\.sock\$//')
	for i in \$VPNS; do
	  status.pl /var/run/fastd-\$i.status | jq . | grep -v "\"address\": " >\$WWWPFAD/data/\$i.json
	done
	EOF
  chmod +x /usr/local/bin/fastd-status
  cat <<-EOF >/etc/cron.d/fastd_update_status 
	*/5 * * * *	root /usr/local/bin/update_peers.py
	* * * * *	root /usr/local/bin/fastd-status
	EOF
}
