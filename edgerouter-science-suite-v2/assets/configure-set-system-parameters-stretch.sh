#!/bin/vbash
source /opt/vyatta/etc/functions/script-template

configure
set system name-server 127.0.0.1
set system name-server 114.114.114.114
set system package repository stretch
set system package repository stretch components "main contrib non-free"
set system package repository stretch distribution stretch
set system package repository stretch url http://ftp.cn.debian.org/debian
set system conntrack expect-table-size 2048
set system conntrack hash-size 32768
set system conntrack table-size 262144
set system conntrack tcp half-open-connections 32768
set system conntrack tcp loose enable
set system conntrack tcp max-retrans 5
delete service dns
set service dns
commit
save

