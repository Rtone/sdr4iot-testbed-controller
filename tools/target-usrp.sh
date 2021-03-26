#!/bin/bash

set -o pipefail
set -e
set -x

main()
{
        local usrp_n="$1"
        local node="$2"
        local base="$(dirname "$0")"     
        [ -n "$usrp_n" ]

        sudo apt-get install -y moreutils # For `ts` 
        sudo apt install -y swig  # For OOT block installation
        sudo /tmp/target-usrp-install-sigmf.sh # For sigmf module

        sysctl -w net.core.wmem_max=1048576
        sysctl -w net.core.rmem_max=50000000

        local us="192.168.${usrp_n}0.1"
        local usrp="192.168.${usrp_n}0.2"

        ip addr add "$us"/24 dev eno2 || \
        ip a l | grep "$us"

        ip link set eno2 up

        local ok=0
        local i
        for i in $(seq 10); do
                echo "#$i"
                if ping -c 1 "$usrp"; then
                ok=1
                break
                fi
                sleep 1
        done
        [ $ok -ne 0 ];
}

main "$@"
exit $?
