# ffs-make-gateway

Setzt auf einem leeren Debian 9 (jessie) mit systemd ein Freifunk-Gateway auf.

Damit der Tinc-VPN-Key auf Github geladen werden kann wird Schreibzugriff auf https://github.com/freifunk-stuttgart/tinc-ffsbb benötigt, Zugriff auf https://github.com/freifunk-stuttgart/tinc wird für die Segment-Tinc-VPNs benötigt

Teile der Konfiguration werden vom [FfsConfigGenerator](https://github.com/freifunk-stuttgart/FfsConfigGenerator) erzeugt, die dort hinterlegte Konfiguration wird an die lokalen Gegebenheiten angepasst.

Ausleitungs-VPN wird keines genutzt, auch DHCP-Server wird kein eigener genutzt. Diese Dienste werden von anderen GWs im Freifunknetz übernommen.

Example:

```bash
./ffs-make-gw --with-lihas-firewall \
              --othergw 172.21.20.1 \
              --directtcp "20:23 43 53 79 80:81 88 110 143 194 220 389 443 464:465 587 531 543:544 554 563 587 636 706 749 873 902:904 981 989:995 1194 1220 1293 1500 1533 1677 1723 1755 1863 2082 2083 2086:2087 2095:2096 2102:2104 3128 3389 3690 4321 4643 5050 5060:5070 5190 5222:5223 5228 5900 6000:6020 6660:6669 6679 6697 8000 8008 8074 8080 8082 8087:8088 8332:8333 8443 8888 9418 9999 10000 11371 19294 19638 33301:33304 50002 64738" \
              --gwid 10 \
              --with-backbone-vpn \
              --dhcp-relay-servers 172.21.20.1
```

### Verfügbare Features:
* DHCP-Relay (isc-relay-agent)
* DNS-Server (bind)
* IPv6-Announcements (radvd)
* Backbone VPN (tinc, bird, bird6) mit Schlüsselerzeugung
* direktes Ausleitung bestimmter TCP-Verbindungen, alles andere geht über ein anderes GW
* Subgateway Unterstützung

### Geplante Features
* eigener DHCP-Server (obsolet, ersetzt durch zentrale DHCP-Server)
* eigenes Ausleitungs VPN

# ffs-make-gateway-buster

Setzt auf einem leeren Debian 10 (buster) ein Freifunk-Gateway auf.

#### Beispiele:
```bash
git clone https://github.com/freifunk-stuttgart/ffs-make-gateway.git
cd ffs-make-gateway
```

Erstellen eines Gateways gw06n02.freifunk-stuttgart.de der in Segment 3 arbeitet:
```bash
./ffs-make-gw-ubuntu --email fehler@ffs.ovh \
                     --gwid 6 \
                     --gwsubid 2 \
                     --segmentlist "03"
```

Erstellen eine Gateways gw08n06.freifunk-stuttgart.de in Segment 1-24 mit direkter Ausleitung:
```bash
./ffs-make-gw-ubuntu --gwid 8 \
                     --gwsubid 6 \
                     --segmentlist "01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24" \
                     --providermode
```

Nachdem das Script ohne Fehler gelaufen ist, ist ein Reboot nötig.


