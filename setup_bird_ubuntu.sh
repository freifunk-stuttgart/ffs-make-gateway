setup_bird() {
cat <<-EOF >/etc/bird/bird.conf
router id 10.191.255.$GWID$GWSUBID;      # eigene IP im tincbb

# Filter definieren
filter ffs_filter {
  krt_metric = 100;
  if net ~ [ 172.21.0.0/16+ ] then accept;
  if net ~ [ 10.190.0.0/15+ ] then accept;
  else reject;
}

protocol kernel {
      learn;                  # Learn all alien routes from the kernel
      persist no;
      scan time 20;           # Scan kernel routing table every 20 seconds
      import filter ffs_filter;
      kernel table 70;        # fuer table stuttgart
      export filter ffs_filter;   # Propagate routes with low metric into kernel table
      device routes;
}

# This pseudo-protocol watches all interface up/down events.
protocol device {
      scan time 10;           # Scan interfaces every 10 seconds
}

protocol ospf ffsBackbone {
      preference 100;         # prio zahl
      rfc1583compat no;       # Metrik gem. OSPFv2, RFC 2328
      stub router no;         # Box macht ggf. auch Transit-Traffic
      tick 1;                 # Topologie-Berechnungen nur alle 1s
      ecmp no;                # Kein Equal-Cost-Multipath, um Problemen mit unterschiedlichen
                              # Uplinks aus dem Weg zu gehen
      import filter ffs_filter;
      export filter ffs_filter;
      area 0.0.0.0 {          # Backbone-Area
          external{
                  0.0.0.0/0;
          };

         interface "ffsbb" {   # Run OSPF over VPN
              cost            100;
              hello           10;
              poll            20;
              retransmit      5;
              priority        10;
              wait            40;
              type            bcast;
              authentication  cryptographic;
              password        "ffsVPN00";
         };
     };
};
EOF

cat <<-EOF >/etc/bird/bird6.conf
off
router id 10.191.255.$GWID$GWSUBID;      # eigene IP im tincbb

# Filter definieren
filter ffs_filter {
  krt_metric = 100;
  if net ~ [ fd21:b4dc:4b00::/40+ ] then accept;
  else reject;
}

protocol kernel {
      learn;                  # Learn all alien routes from the kernel
      persist no;
      scan time 20;           # Scan kernel routing table every 20 seconds
      import filter ffs_filter;
      kernel table 70;        # fuer table stuttgart
      export filter ffs_filter;   # Propagate routes with low metric into kernel table
      device routes;
}

# This pseudo-protocol watches all interface up/down events.
protocol device {
      scan time 10;           # Scan interfaces every 10 seconds
}

protocol ospf ffsBackbone {
      preference 100;         # prio zahl
      rfc1583compat no;       # Metrik gem. OSPFv2, RFC 2328
      stub router no;         # Box macht ggf. auch Transit-Traffic
      tick 1;                 # Topologie-Berechnungen nur alle 1s
      ecmp no;                # Kein Equal-Cost-Multipath, um Problemen mit unterschiedlichen
                              # Uplinks aus dem Weg zu gehen
      import filter ffs_filter;
      export filter ffs_filter;
      area 1 {          # Backbone-Area
          external{
                  ::/0;
          };

         interface "ffsbb" {   # Run OSPF over VPN
              cost            100;
              hello           10;
              poll            20;
              retransmit      5;
              priority        10;
              wait            40;
              type            bcast;
         };
     };
};
EOF

}

