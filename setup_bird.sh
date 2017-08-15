setup_bird() {
  cat <<-EOF >/etc/bird/bird_routerid.conf
	router id router id 10.191.255.$GWID;
	EOF
  cat <<-EOF >/etc/bird/bird_kernel_stuttgart.conf
	table tk_stuttgart;
	protocol kernel k_stuttgart {
	    learn;            # Learn all alien routes from the kernel
	    persist;        # Don't remove routes on bird shutdown
	    scan time 20;        # Scan kernel routing table every 20 seconds
	    import all;        # Default is import all
	    kernel table 70;    # Kernel table to synchronize with (default: main)
	    table tk_stuttgart;
	    export filter {
	        if net = 0.0.0.0/0 then { # no default route
	            reject;
	        }
	        krt_metric = 100;    
	        accept;
	    };
	    device routes;
	}
	EOF
  cat <<-EOF >/etc/bird/bird_device.conf
	protocol device {
	    scan time 10;        # Scan interfaces every 10 seconds
	    table tk_stuttgart
	}
	EOF
  cat <<-EOF >/etc/bird/bird_ospf_stuttgart.conf
	protocol ospf ffsBackbone {
	    table tk_stuttgart;
	    preference 100;
	    import filter {
	        # Wir lennen alles was eine Netzmaske /8 oder schlechter hat:
	        if net ~ [ 0.0.0.0/0{0,7} ] then reject;
	        accept;     
	    };
	    export filter {
	        # Wir lennen alles was eine Netzmaske /8 oder schlechter hat:
	        if net ~ [ 0.0.0.0/0{0,7} ] then reject;
	        accept;     
	        ospf_metric1 = 100;
	    };
	    rfc1583compat no;    # Metrik gem. OSPFv2, RFC 2328
	    stub router no;        # Box macht ggf. auch Transit-Traffic
	    tick 1;            # Topologie-Berechnungen nur alle 1s
	    ecmp no;        # Kein Equal-Cost-Multipath, um Problemen mit unterschiedlichen 
	                # Uplinks aus dem Weg zu gehen
	    area 0.0.0.0 {        # Backbone-Area
	        external {
	            0.0.0.0/0;
	        };
	        
	        interface "ffsl3" {
	            cost        100;
	            hello        10;
	            poll        20;
	            retransmit     5;
	            priority    10;
	            wait        40;
	            type        bcast;
	            authentication    cryptographic;
	            password    "ffsVPN00";
	        };
	        
	    };
	};
	EOF

  if grep -q "router id 10.191.255.$GWID;" /etc/bird/bird.conf; then
    sed -i 's/^router id .*/router id 10.191.255.'$(($GWID*10+$GWSUBID))';/' /etc/bird/bird.conf
  fi
  if grep -q "router id 10.191.255.$GWID;" /etc/bird/bird6.conf; then
    sed -i 's/^router id .*/router id 10.191.255.'$(($GWID*10+$GWSUBID))';/' /etc/bird/bird6.conf
  fi
  systemctl enable bird
  systemctl enable bird6
}
