#!/bin/bash

setup_logrotate() {
    if [ -e /etc/logrotate.d/rsyslog ]; then
	if egrep -q '(daily|weekly|monthly)' /etc/logrotate.d/rsyslog; then
	    sed -i 's/\(daily\|weekly\|monthly\)/hourly/g; s/rotate.*[0-9]\+/rotate 24/' /etc/logrotate.d/rsyslog
	fi
    fi
    if [ ! -e /etc/cron.hourly/logrotate ]; then
	ln -s /etc/cron.daily/logrotate /etc/cron.hourly/logrotate
    fi
}
