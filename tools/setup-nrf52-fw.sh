#!/bin/bash

set -o pipefail
set -e
set -x

setup_nrf52_fw_zigbee()
{
        local node="$1"
        local node_type="$2"
        local zigbee_fw="$3"
        [ -n "$zigbee_fw" ]
        rsync -e 'ssh -F ssh-config' -r --exclude '.git' --exclude '*.iq' --exclude '*.pyc' "$zigbee_fw" "$node:/tmp"
        ssh -F ssh-config "$node" "sudo nrfjprog -f NRF52 --chiperase --program /tmp/light_control/$node_type/hex/nrf52840_xxaa.hex --reset"
        return $?
}

setup_nrf52_fw_ble()
{
        local node="$1"
        rsync -e 'ssh -F ssh-config' -r --exclude '.git' --exclude '*.iq' --exclude '*.pyc' "$ble_fw" "$node:/tmp"
        echo "Flashing SoftDevice ..."
        ssh -F ssh-config "$node" "sudo nrfjprog -f nrf52 --program /tmp/s140_nrf52_7.2.0_softdevice.hex --sectorerase"
        echo "Flashing BLE firmware ..."
        ssh -F ssh-config "$node" "sudo nrfjprog -f nrf52 --program /tmp/ble_app_blinky_pca10056_s140.hex --sectorerase --reset"
        return $?
}

die()
{
        (
                [ $# -ne 0 ] && {
                        echo "$@"
                        echo ""
                }
                echo "Usage: $0 [-c|-r|-e] <node>"
                echo ""
                echo "Options:"
                echo " -c <node> Define node as zigbee coordinator"
                echo " -r <node> Define node as zigbee router"
                echo " -e <node> Define node as zigbee end device"
                echo " -b <node> Define node as BLE end device"
                
        ) >&2
        [ $# -eq 0 ] && exit 0
        exit 1
}

main()
{
	
        local zigbee_fw zigbee_coord_node zigbee_router_node zigbee_end_node
        local ble_fw ble_node
        local err=0
        while getopts "hc:r:e:b:" opt; do
            case $opt in
            c) zigbee_coord_node=${OPTARG};;
            r) zigbee_router_node=${OPTARG};;
            e) zigbee_end_node=${OPTARG};;
            b) ble_node=${OPTARG};;
            h) die;;
            *) die "Invalid arg: $opt";;
            esac
        done
        shift $((OPTIND - 1))

        zigbee_fw="$(CONF=../conf.yml "$(dirname "$0")"/get-field.sh 'user' 'zigbee_fw')"
        ble_fw="$(CONF=../conf.yml "$(dirname "$0")"/get-field.sh 'user' 'ble_fw')"

        if [ -n "$zigbee_coord_node" ]; then
                echo "Flash Zigbee fw (Using coordinator node)"
                setup_nrf52_fw_zigbee "$zigbee_coord_node" "light_coordinator" "$zigbee_fw"  
        elif [ -n "$zigbee_router_node" ]; then
                echo "Flash Zigbee firmware (Using router node)"
                setup_nrf52_fw_zigbee "$zigbee_router_node" "light_switch" "$zigbee_fw"
        elif [ -n "$zigbee_end_node" ]; then
                echo "Flash Zigbee firmware (Using end device node)" 
                setup_nrf52_fw_zigbee "$zigbee_end_node" "light_bulb" "$zigbee_fw"
        elif [ -n "ble_node" ]; then
                [ -n "$ble_fw" ]
                echo "Flash BLE firmware" 
                setup_nrf52_fw_ble "$ble_node"
        else
                echo "Missing node"
                return 1
        fi    
        
}
main "$@"
exit $?
