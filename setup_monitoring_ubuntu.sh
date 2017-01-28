setup_monitoring_statuspl() {
cat <<-EOF >/usr/local/bin/status.pl
#!/usr/bin/perl -w
use strict;
use IO::Socket::UNIX qw( SOCK_STREAM );
\$ARGV[0] or die("Usage: status.pl <socket>\n");
my \$socket = IO::Socket::UNIX->new(
  Type => SOCK_STREAM,
  Peer => \$ARGV[0],
)
  or die("Can't connect to server: \$!\n");
foreach my \$line (<\$socket>) {
  print \$line;
}
EOF
chmod +x /usr/local/bin/status.pl
}

setup_monitoring_munin() {

setup_monitoring_statuspl

ensureline "allow ^10\.191\.255\.241$" /etc/munin/munin-node.conf
ensureline "allow ^10\.191\.255\.242$" /etc/munin/munin-node.conf
ensureline "allow ^10\.191\.255\.243$" /etc/munin/munin-node.conf

ensureline "\[fastdall]" /etc/munin/plugin-conf.d/munin-node
ensureline "  user root" /etc/munin/plugin-conf.d/munin-node

cat <<EOF >/usr/share/munin/plugins/fastdall
#!/bin/sh

VPN="$(echo " $SEGMENTLIST" | sed 's/ / vpn/g')"
#VPN="vpn00 vpn01 vpn02 vpn03 vpn04 vpn00bb vpn01bb vpn02bb vpn03bb vpn04bb"

case \$1 in
   config)
        cat <<'EOM'
graph_title Fastd connections given
graph_vlabel connection count
graph_category ffsfastd
graph_args --base 1000 -l 0
graph_scale no
EOM
for i in \$VPN ; do
  echo "\$i.label Fastd \$i"
  echo "\$i.info Fastd vpn tunnels"
done
        exit 0;;
esac

for i in \$VPN ; do
  printf "\$i.value "
  /usr/local/bin/status.pl /var/run/fastd-\$i.status | jq . | grep established | wc -l
done
EOF
chmod +x /usr/share/munin/plugins/fastdall
if [ ! -e /etc/munin/plugins/fastdall ]; then
  ln -s /usr/share/munin/plugins/fastdall  /etc/munin/plugins/fastdall
fi

}

setup_monitoring_updateff() {
if [ ! -e /usr/local/bin/update_peers.py ]; then
  wget https://raw.githubusercontent.com/poldy79/FfsScripts/master/update_peers.py -nd -P /usr/local/bin/
  chmod +x /usr/local/bin/update_peers.py
fi

mkdir -p /var/www/html/data
cat <<EOF >/usr/local/bin/update-ff
#!/bin/sh
wwwpfad="/var/www/html"
VPNS="$(echo " $SEGMENTLIST" | sed 's/ / vpn/g')"
#       Endlosschleife
while : ; do
   ## ffs Peers aktualisieren
   cd /etc/fastd/peers
   back=\$( git pull )
   echo "fastd-peers: \$back"
   /usr/local/bin/update_peers.py --repo /etc/fastd/peers
   ## ffsbb aktualisieren
   cd /root/tinc-ffsbb/
   back=\$( git pull )
   echo "tinc-ffsbb: \$back"
   tincd -n ffsbb -k HUP
   # Status veroeffentlichen
   for i in \$VPNS; do
     status.pl /var/run/fastd-\$i.status | jq . | grep -v "\"address\": " >\$wwwpfad/data/\$i.json
   done
   echo "*** fertig ***"
   sleep 120
done
EOF
chmod +x /usr/local/bin/update-ff
ensureline_insert "/usr/local/bin/update-ff &" /etc/rc.local
}

setup_monitoring_checktasks() {
cat <<EOF >/usr/local/bin/check-tasks
#! /bin/bash
  ####        Alle wichtigen Task pruefen und bei Bedarf neu starten und per Email informieren

  ####       Variablen anpassen!
  EMAIL=$EMAIL              # an wen die Antwortmails gehen sollen
  DNSIP=\$(ifconfig br$(echo "$SEGMENTLIST" | cut -d " " -f 1) | grep 'inet [Aa]d' | cut -d: -f2 | awk '{print \$1}')  # IP Adresse des DNS Servern
  DNSANFRAGE=web.de                 # Domainname Anfrage
  DNSBACK=212.227                   # IP die als Antwort auf DNSANFRAGE zurück kommen muss
  IFBAT="$(echo " $SEGMENTLIST" | sed 's/ / bat/g')"   # Alle Fastd Interfaces
  FASTDANZAHL=$(($(echo $SEGMENTLIST | wc -w) * 2 ))                # Anzahl der Fastd Instanzen die laufen
  OVPN=/etc/openvpn                 # Pfad zu Openvpn Konfigs

  ####        auf standard setzen
  VPNERROR=0
  VPNDOWN=1
  EMAILZAHL=0

  if [ -n "\$1" ]; then
      TESTMODE=\$1
      echo "start Testmode"
  fi

  #       Endlosschleife
  while : ; do

      ####   ANTWORT auf "" setzen
      ANTWORT=""


      ####    fastd pruefen
      PRG="fastd"
      BACK=\$(ifconfig | grep vpn | wc -l)
      echo -n "check \$PRG: "
      if [ "\$BACK" != \$FASTDANZAHL ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
          service \$PRG stop
          sleep 1
          service \$PRG start
          sleep 5
      else
          echo "OK"
      fi

      ####    tinc pruefen
      PRG="tinc"
      BACK=\$(pgrep -x tincd)
      echo -n "check \$PRG: "
      if [ -z "\$BACK" ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
          service \$PRG restart
          sleep 5
      else
          echo "OK"
      fi

      ####    isc-dhcp-relay pruefen
      PRG="isc-dhcp-relay"
      BACK=\$(pgrep -x dhcrelay)
      echo -n "check \$PRG: "
      if [ -z "\$BACK" ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
          service \$PRG restart
          sleep 5
      else
          echo "OK"
      fi

      ####    bird pruefen
      PRG="bird"
      BACK=\$(pgrep -x \$PRG)
      echo -n "check \$PRG: "
      if [ -z "\$BACK" ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
          service \$PRG restart
          sleep 5
      else
          echo "OK"
      fi

      ####    bird6 pruefen
      PRG="bird6"
      BACK=\$(pgrep -x \$PRG)
      echo -n "check \$PRG: "
      if [ -z "\$BACK" ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
          service \$PRG restart
          sleep 5
      else
          echo "OK"
      fi

      ####    radvd pruefen
      PRG="radvd"
      BACK=\$(pgrep -x \$PRG)
      echo -n "check \$PRG: "
      if [ -z "\$BACK" ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
          service \$PRG restart
          sleep 5
      else
          echo "OK"
      fi

      ####    dnsmasq pruefen
      PRG="dnsmasq"
      BACK=\$(pgrep -x \$PRG)
      echo -n "check \$PRG: "
      if [ -z "\$BACK" ] ; then
              echo "Error"
              ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
              service \$PRG restart
              sleep 5
      else
          echo "OK"
      fi

      ####    ntpd/openntpd pruefen
      PRG="ntp"
      BACK=\$(pgrep -x ntpd)
      echo -n "check \$PRG: "
      if [ -z "\$BACK" ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG nicht gestartet\nFehler: \$BACK\n\n"
          service \$PRG restart
          sleep 5
      else
          echo "OK"
      fi

      ####    dnsmasq dns Anfragen pruefen
      PRG="dnsmasq"
      BACK=\$(nslookup \$DNSANFRAGE \$DNSIP)
      ZAHL=\$(echo \$BACK | grep -c \$DNSBACK)
      echo -n "check DNS-Anfrage: "
      if [ "\$ZAHL" -gt 0 ] ; then
          echo "Error"
          ANTWORT+="Fehler: \$PRG ANTWORTet nicht auf DNS-Anfragen\nFehler: \$BACK\n\n"
          service \$PRG restart
          sleep 5
      else
          echo "OK"
      fi

      ####    openvpn pruefen
      PRG="openvpn"
      ip=\$(ip -o -4 addr list tun0 | awk '{print \$4}' | cut -d/ -f1)
      #ip=\$(ip -o -4 addr list tun0 | awk '{gsub("/.*","",\$4); print \$4}')
      echo -n "check ping web.de: "
      BACK=\$(ping -c2 -I \$ip web.de 2>&1)
      ZAHL=\$?
      if [ "\$ZAHL" -gt 0 ] ; then
          echo "Error"
          echo -n "check ping 8.8.8.8: "
          BACK=\$(ping -c2 -I \$ip 8.8.8.8 2>&1)
          ZAHL=\$?
      fi
      if [ "\$ZAHL" -gt 0 ] ; then
          echo "Error"
      else
          echo "OK"
          echo -n "check masquerate: "
          nat=\$(iptables -vnt nat -L | grep MASQUERADE | wc -l)
          if [ "\$nat" -ne 1 ] ; then
              echo "Error"
              ZAHL=99
              BACK=\$(iptables -vnt nat -L)
          fi
      fi
      if [ "\$ZAHL" -gt 0 ] ; then
          ANTWORT+="Fehler: \$PRG funktioniert nicht korrekt\nFehler: \$BACK\n\n"
          service \$PRG restart
          ((VPNERROR++))
          if [ \$VPNERROR -gt 1 ] ; then
              # Config wechseln wenn vpn erneut down
              mv \$OVPN/00.conf \$OVPN/00.ovpn
              mv \$OVPN/01.ovpn \$OVPN/00.conf
              mv \$OVPN/02.ovpn \$OVPN/01.ovpn
              mv \$OVPN/03.ovpn \$OVPN/02.ovpn
              mv \$OVPN/00.ovpn \$OVPN/03.ovpn
              service \$PRG restart
              ANTWORT+="\$PRG Config gewechselt nach \$(cat \$OVPN/00.conf | grep remote)\n\n"
          fi
          if [ \$VPNERROR -gt 3 ] ; then
              # Gateway deaktivieren wenn zu viele Fehler
              for ZAHL in \$IFBAT ; do
                  batctl -m \$ZAHL gw off
                  ANTWORT+="\$ZAHL: gw off\n\n"
              done
              VPNERROR=0
              VPNDOWN=1
          fi
      else
          echo "OK"
          VPNERROR=0
          if [ \$VPNDOWN -gt 0 ] ; then
              # Gateway aktivieren
              for ZAHL in \$IFBAT ; do
                  batctl -m \$ZAHL gw server 64mbit/64mbit
                  ANTWORT+="\$ZAHL: gw server 64mbit/64mbit\n\n"
              done
              VPNDOWN=0
          fi
      fi


      #       Email senden wenn Fehler auftrat
      if [ -n "\$ANTWORT" ]; then
          ((EMAILZAHL++))             # Email Zaehler
          if [ \$EMAILZAHL -le 11 ] ; then
              echo "Sende Email an \$EMAIL"
              echo -e "\$ANTWORT" | mutt -s "Fehler auf Server \$HOSTNAME" \$EMAIL
          fi
      else
          EMAILZAHL=0
      fi

      if [ -z "\$TESTMODE" ]; then
          sleep 50
      fi
      sleep 10

  done

EOF
chmod +x /usr/local/bin/check-tasks
ensureline_insert "/usr/local/bin/check-tasks &" /etc/rc.local
}
