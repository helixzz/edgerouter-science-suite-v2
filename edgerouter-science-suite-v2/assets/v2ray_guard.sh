#!/bin/bash
while true; do
    if ! pgrep v2ray; then
        logger "V2ray process not found. Waiting for 10s..."
        sleep 3
        continue
    fi
    pid=$(pgrep v2ray)
    logger "Found PID of v2ray process: $pid"
    vmrss=$(cat /proc/$pid/status | grep VmRSS | awk '{print $2}')
    echo "Current VmRSS of v2ray process: $vmrss"
    if [ $vmrss -gt 400000 ]; then
        /bin/kill -9 $pid
        logger "Killed v2ray process."
    fi
    sleep 3
done
