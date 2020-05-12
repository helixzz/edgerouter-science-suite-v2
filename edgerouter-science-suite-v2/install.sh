#!/bin/bash
# Science Suite for EdgeRouter Series (MIPS64 Platform)
# HeliXZz, 2020

function log () {
    echo $1 | tee -a $LOGFILE
}

function welcome () {
    log "Science Suite for EdgeRouter Series (MIPS64 platform)"
    log "You can find the installation log file at $LOGFILE."
    log "If you encountered any problem please attach the log file when contacting support."
    read -p "Please hit ENTER when you're ready to begin installation."
}

function check-shell () {
    log "Checking SHELL..."
    EXEC_SHELL=$(readlink /proc/$$/exe)
    if [ "$EXEC_SHELL" == "/bin/bash" ]; then
        log "SHELL checking passed: $EXEC_SHELL"
    else
        log "ERROR: Using unsupported SHELL $EXEC_SHELL. Please ensure running the script by /bin/bash."
    fi
}

function check-root () {
    if [ $(id -u) -ne 0 ]; then
        log "ERROR: Root privilege required."
        exit -1
    fi
}

function check-system-version () {
    log "Checking system version..."
    OS_RELEASE_FILE="/etc/os-release"
    VERSION_FILE="/etc/version"
    source $OS_RELEASE_FILE
    OS_RELEASE=$(echo $PRETTY_NAME)
    VERSION=$(cat /etc/version)
    KERNEL_VERSION=$(uname -r)
    log "OS Release: $OS_RELEASE"
    log "EdgeOS Version: $VERSION"
    log "Kernel Version: $KERNEL_VERSION"
    /opt/vyatta/bin/vyatta-op-cmd-wrapper show version >> $LOGFILE
}

function install-tproxy-modules () {
    log "Installing TPROXY kernel modules..."
    if [ "$KERNEL_VERSION" == "3.10.107-UBNT" ]; then
        log "Current kernel version supported. Copying files..."
        chmod 644 assets/modules/*.ko
        cp assets/modules/*.ko /lib/modules/3.10.107-UBNT/kernel/net/netfilter/
        cat assets/modules/tproxy.conf >> /etc/modules
        depmod -a
        modprobe nf_tproxy_core
        modprobe xt_TPROXY
        modprobe xt_socket
    else
        log "WARNING: Current kernel version $KERNEL_VERSION not supported."
        log "You can proceed with installation, but UDP forwarding will not work."
        log "We recommend you to install UBNT FW 1.10.x to get proper kernel version."
        log "Alternatively, you can build xt_TPROXY/xt_socket modules yourself."
    fi
}

function check-ulimit () {
    log "Checking ulimit..."
    ULIMIT=$(ulimit -n)
    if [ $ULIMIT -lt 1048576 ]; then
        log "Current maximum number of open files $ULIMIT is too small."
        log "Increasing limits in /etc/security/limits.conf ..."
        echo "*               soft    nofile          1048576" >> /etc/security/limits.conf
        echo "*               hard    nofile          1048576" >> /etc/security/limits.conf
        ulimit -n 1048576
        ULIMIT=$(ulimit -n)
        if [ $ULIMIT -lt 1048576 ]; then
            log "A reboot is needed to make the new configuration takes effect."
            log "Please retry installation after reboot. Reminder: Always save your configuration before rebooting!"
            exit -1000
        fi
    fi
}

function configure-set-system-parameters () {
    log "Importing system configuration..."
    /bin/vbash assets/configure-set-system-parameters.sh
}

function check-network () {
    log "Checking network connectivity..."
    if ! ping -c 3 114.114.114.114 > /dev/null; then
        log "ERROR: Cannot reach the Internet. Please check network."
        exit -2001
    fi
    if ! host connect.helixzz.com > /dev/null; then
        log "ERROR: Cannot reach the Internet. Please check DNS."
        exit -2002
    fi
}

function install-dnsmasq () {
    log "Installing DNSMASQ..."
    cp -r assets/dnsmasq.d /config/
    cp assets/dnsmasq.conf /etc/
    log "Testing DNSMASQ configuration..."
    if /usr/sbin/dnsmasq --test 2>&1 | grep "syntax check OK."; then
        log "DNSMASQ configuration test passed."
    else
        /usr/sbin/dnsmasq --test 2>&1 >> $LOGFILE
        log "DNSMASQ configuration test failed. Installation aborted. Please contact support."
    fi
    cp assets/dnsmasq-supervisor.conf /etc/supervisor/conf.d/
}

function install-v2ray () {
    log "Copying V2RAY files..."
    cp -r assets/v2ray /config/
    read -p "Enter V2RAY server address: " V2RAY_SERVER_ADDR
    read -p "Enter V2RAY server port: " V2RAY_SERVER_PORT
    read -p "Enter V2RAY user ID: " V2RAY_USER_ID
    sed -i "s/V2RAY_SERVER_ADDRESS/$V2RAY_SERVER_ADDR/g" /config/v2ray/config.json
    sed -i "s/V2RAY_SERVER_PORT/$V2RAY_SERVER_PORT/g" /config/v2ray/config.json
    sed -i "s/V2RAY_ACCOUNT_ID/$V2RAY_USER_ID/g" /config/v2ray/config.json
    log "Testing V2RAY configuration..."
    if /config/v2ray/v2ray -test -config /config/v2ray/config.json 2>&1 | grep "Configuration OK."; then
        log "V2RAY configuration test passed."
    else
        /config/v2ray/v2ray -test -config /config/v2ray/config.json 2>&1 >> $LOGFILE
        log "V2RAY configuration test failed. Please ensure the server address, port, and user ID you entered is correct, then retry installation."
        exit -1
    fi
    cp assets/v2ray/v2ray.conf /etc/supervisor/conf.d/
}

function install-supervisor () {
    log "Installing Supervisor..."
    # Alternatively, use online installation...
    # apt-get -y -qq update
    # apt-get -y -qq install supervisor
    dpkg --force-all -i assets/supervisor/python-medusa_0.5.4-7_all.deb 2>&1 >> $LOGFILE 
    dpkg --force-all -i assets/supervisor/python-meld3_0.6.5-3.1_mips.deb 2>&1 >> $LOGFILE
    dpkg --force-all -i assets/supervisor/python-pkg-resources_0.6.24-1_all.deb 2>&1 >> $LOGFILE
    dpkg --force-all -i assets/supervisor/python-support_1.0.15_all.deb 2>&1 >> $LOGFILE
    dpkg --force-all -i assets/supervisor/supervisor_3.0a8-1.1+deb7u1_all.deb 2>&1 >> $LOGFILE
    cp assets/supervisord.conf /etc/supervisor/supervisord.conf
    /etc/init.d/supervisor stop
    /etc/init.d/supervisor start
    if ps -ef | grep -v grep | grep supervisor; then
        log "Supervisor configured."
    else
        log "Supervisor is not running normally. Please check the configuration file or contact support."
        exit -3000
    fi
}

function install-frp () {
    log "Installing frp..."
    cp -r assets/frp /config/
    read -p "Enter frp remote port: " FRP_PORT
    read -p "Enter frp privilege token: " FRP_TOKEN
    FRP_HOSTNAME="$(hostname -f)-$HWSN"
    sed -i "s/FRP_PORT/$FRP_PORT/g" /config/frp/frpc.ini
    sed -i "s/FRP_HOSTNAME/$FRP_HOSTNAME/g" /config/frp/frpc.ini
    sed -i "s/FRP_TOKEN/$FRP_TOKEN/g" /config/frp/frpc.ini
    cp assets/frp/frpc.conf /etc/supervisor/conf.d
}

function install-control-scripts () {
    log "Installing control scripts..."
    cp assets/etc/init.d/science /etc/init.d/
    chmod 755 /etc/init.d/science
    cp assets/chnroute.txt /config/
    update-rc.d science enable
    /etc/init.d/science stop
    /etc/init.d/science start
}

function verify-result () {
    log "Verifing installation..."
    /etc/init.d/supervisor restart
    log "Try cURL www.google.com..."
    curl -IL www.google.com
    log "Try cURL www.baidu.com..."
    curl -IL www.baidu.com 
    log "Installation completed."
}

# Initialize
DATETIME=$(date +%Y%m%d-%H%M%S)
LOGFILE="/tmp/science-install-$DATETIME.log"
if [ -e /opt/vyatta/bin/vyatta-op-cmd-wrapper ]; then
    HWSN=$(/opt/vyatta/bin/vyatta-op-cmd-wrapper show version | grep S/N | awk '{print $3}')
fi

welcome
check-shell
check-root
check-system-version
install-tproxy-modules
check-ulimit
configure-set-system-parameters
check-network
install-supervisor
install-v2ray
install-dnsmasq
# install-frp # Optional
install-control-scripts
verify-result

