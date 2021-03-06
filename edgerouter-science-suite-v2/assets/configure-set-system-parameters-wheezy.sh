#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

configure
set system name-server 127.0.0.1
set system name-server 114.114.114.114
set system time-zone Asia/Shanghai
delete system package repository
set system package repository
set system package repository wheezy
set system package repository wheezy components "main contrib non-free"
set system package repository wheezy distribution wheezy
set system package repository wheezy url http://archive.debian.org/debian
set system conntrack expect-table-size 2048
set system conntrack hash-size 32768
set system conntrack table-size 262144
set system conntrack tcp half-open-connections 32768
set system conntrack tcp loose enable
set system conntrack tcp max-retrans 5
set service snmp community SNMP4mzseed
set service snmp listen-address 0.0.0.0
set system ntp server time1.aliyun.com
set system ntp server time1.apple.com
delete service dns
set service dns
commit
save

