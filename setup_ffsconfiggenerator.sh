setup_ffsconfiggenerator_config() {
if [ ! -d FfsConfigGenerator ]; then
  pip2 install --upgrade netaddr
  git clone https://github.com/freifunk-stuttgart/FfsConfigGenerator.git
  cd FfsConfigGenerator
else
  cd FfsConfigGenerator
  git checkout -- config.json
  git pull
fi
segmentarray=$(echo $SEGMENTLIST | sed 's/ /, /g')
python -c '
import json, sys
GWID='$GWID'
GWSUBID='$GWSUBID'
fp = open("config.json","rb")
config = json.load(fp)
fp.close()
if ( "$GWID,$GWSUBID" not in config["gws"] ):
  fp = open("config.json","wb")
  config["gws"]["'$GWID','$GWSUBID'"] = {}
  config["gws"]["'$GWID','$GWSUBID'"]["legacyipv4"] = "'$LEGIP'"
  config["gws"]["'$GWID','$GWSUBID'"]["legacyipv6"] = "fd21:b4dc:4b1e::a38:'$GWLID'"
  config["gws"]["'$GWID','$GWSUBID'"]["externalipv4"] = "'$EXT_IP_V4'"
  config["gws"]["'$GWID','$GWSUBID'"]["externalipv6"] = "'$EXT_IPS_V6'"
  config["gws"]["'$GWID','$GWSUBID'"]["ipv4start"] = "172.21.'$((4*$GWID))'.2"
  config["gws"]["'$GWID','$GWSUBID'"]["ipv4end"] = "172.21.'$((4*$((GWID+1))-1))'.254"
  config["gws"]["'$GWID','$GWSUBID'"]["segments"] = ['$segmentarray']
  json.dump(config, fp, indent=2)
  fp.close()
'
}
