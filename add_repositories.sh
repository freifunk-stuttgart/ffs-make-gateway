add_apt_repositories() {
  apt-get install apt-transport-https
  ensureline "deb http://deb.debian.org/debian buster-backports main" /etc/apt/sources.list.d/buster-backports.list
  # no need with buster
  if [ $(uname -r | awk '$1 > "4.19"' | wc -l ) -lt 1 ]; then
    ensureline "deb http://ppa.launchpad.net/freifunk-mwu/freifunk-ppa/ubuntu trusty main" /etc/apt/sources.list.d/freifunk.list
    ensureline "deb-src http://ppa.launchpad.net/freifunk-mwu/freifunk-ppa/ubuntu trusty main" /etc/apt/sources.list.d/freifunk.list
    ensureline "deb http://repo.universe-factory.net/debian/ sid main" /etc/apt/sources.list.d/freifunk.list
    ensureline "deb http://debian.mirrors.ovh.net/debian/ jessie-backports main" /etc/apt/sources.list.d/jessie-backports.list
  fi
  if [ "x$OPT_FWLIHAS" == "x1" ] || [ "x$OPT_CHECKMK" == "x1" ] ; then
    apt update
    apt install extrepo
    extrepo enable lihas
  fi
}
add_apt_preference() {
	echo
#  cat <<'EOF' >/etc/apt/preferences.d/alfred
#Package: alfred
#Pin:  release n=jessie-backports
#Pin-Priority:  500
#EOF
}
add_apt_keys() {
	echo
#  apt-key adv --keyserver keyserver.ubuntu.com --recv 16EF3F64CB201D9C
#  apt-key adv --keyserver keyserver.ubuntu.com --recv B976BD29286CC7A4
}
