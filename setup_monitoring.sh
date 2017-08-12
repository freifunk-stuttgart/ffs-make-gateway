setup_monitoring_vnstat() {
  replaceline "BandwidthDetection 1" "BandwidthDetection 0" /etc/vnstat.conf
}
setup_monitoring_updateff() {
  mkdir -p /var/www/html/data
  cat >/usr/local/bin/update-ff <<-EOF
	#!/bin/bash
	export LC_ALL=C
	WWWPFAD="$WWWPFAD"
	git -C $FFSGIT/peers-ffs pull > /dev/null
	git -C $FFSGIT/tinc pull > /dev/null
	killall -HUP tincd
	
	TEMPDIR=\$(mktemp -d /dev/shm/fastd-status-export.XXXXXXXXXX)
	FASTD_STATUS_OUTDIR='\$WWWPFAD/fastd'
	if [ -e /etc/default/freifunk ]; then
	        . /etc/default/freifunk
	fi
	if [ ! -d "\$FASTD_STATUS_OUTDIR" ]; then
	  if [ -e "\$FASTD_STATUS_OUTDIR" ]; then
	    echo "'\$FASTD_STATUS_OUTDIR' exists and is no directory" >&2
	    exit 1
	  fi
	  mkdir -p "\$FASTD_STATUS_OUTDIR"
	fi
	/usr/local/bin/update_peers.py --repo /var/lib/ffs/git/peers-ffs
	# find all active fastd status sockets
	for fastdsocket in \$(find /etc/fastd/ -name fastd.conf |
	xargs sed -n '/^status\s\+socket\s\+"/{s#^status\s\+socket\s\+"\([^"]\+\)";#\1#; p}'); do
	  if fuser -s \$fastdsocket 2>/dev/null; then
	    # active fastd
	    fastdname=\$(sed 's#^.*/##; s#^fastd-##; s#\.sock\$##' <<<\$fastdsocket)
	    /usr/local/bin/fastd-clean.py -i <(socat "\$fastdsocket" -) -o "\$FASTD_STATUS_OUTDIR"/"\$fastdname".json.new
	    mv "\$FASTD_STATUS_OUTDIR"/"\$fastdname".json.new "\$FASTD_STATUS_OUTDIR"/"\$fastdname".json
	  fi
	done
	rm -rf \$TEMPDIR
EOF
  chmod +x /usr/local/bin/update-ff
  ensureline_insert "/usr/local/bin/update-ff &" /etc/rc.local
}
setup_monitoring() {
cat <<'EOF' >/usr/local/bin/gw-watchdog
#!/bin/bash

( LC_ALL=C

error () {
        echo "ERROR $*"
}

[ -e /etc/default/freifunk ] && . /etc/default/freifunk

# check ffsbb-tinc
# pid of tinc
TINC_PID=$(ps x | awk '$5 ~ /tincd$/ && /-n ffsbb/ {print $1}')
if [ 'x'"$TINC_PID" == 'x' ]; then
        # no tinc, restart
        error "tinc ffsbb down, restart"
        /sbin/ifdown --force ffsbb
        /sbin/ifup ffsbb
fi
if ! host www.freifunk-stuttgart.de 127.0.0.1 > /dev/null 2>&1; then
	killall rndc
	killall -9 named
	/usr/sbin/service bind9 restart
fi
# check interfaces
# 'auto'-interfaces must be present
INTERFACES="$INTERFACES $(egrep -h '^(auto)' /etc/network/interfaces.d/* /etc/network/interfaces | sed 's/^\(auto\|allow-hotplug\)[ \t]*//')"
for iface in $INTERFACES; do
        case $iface in
                vpn*)
                        # fastd muss laufen
                        if ! systemctl status fastd@$iface >/dev/null; then
                                error "/sbin/ifdown --force $iface"
                                /sbin/ifdown --force $iface
                                error "systemctl start fastd@$iface"
                                systemctl start fastd@$iface
                        fi
                        # batman muss das Interface haben
                        BATIF=bat$(sed 's/\(vpn\|bb\|ip6\)//g' <<<$iface)
                        if ! /usr/sbin/batctl -m $BATIF if | grep -q "$iface:"; then
                                error "/usr/sbin/batctl -m $BATIF if add $iface"
                                /usr/sbin/batctl -m $BATIF if add $iface
                        fi
                        ;;
        esac
        if ! ip l l dev $iface | egrep -q 'state (UP|UNKNOWN)'; then
                /sbin/ifdown --force $iface
                /sbin/ifup $iface
        fi
done
if ! pgrep named > /dev/null; then
	service bind9 restart
fi
if ! host www.freifunk-stuttgart.de 127.0.0.1 > /dev/null 2>&1; then
	killall rndc
	killall -9 named
	/usr/sbin/service bind9 restart
fi
tcpdump -n -i any port 67 or port 68 -c 20 2>/dev/null |
awk 'BEGIN {req=0; rep=0; answer=0} 
     $7 ~ /^Request$/ {req++} 
     $7 ~ /^Reply$/ {rep++} 
     $3 ~ /67$/ && $5 ~ /68:$/ {answer++} 
     END {print req " " rep " " answer; exit answer}' >/dev/null
if [ $? == 0 ]; then
    systemctl restart isc-dhcp-relay.service
fi
) 2>&1 | logger --tag "$0"
EOF
chmod +x /usr/local/bin/gw-watchdog
ensureline "* * * * * root /usr/local/bin/gw-watchdog" /etc/cron.d/gw-watchdog
}
