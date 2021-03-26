#!/bin/bash

set -o pipefail
set -e
set -x

fw_client()
{
        local node="$1"
        local fw_duration="$2"
        local zigbee_channel="$3"
        local base
        base="$(dirname "$0")"
        scp -F ssh-config "$base/target-fw.sh" "$node:/tmp"
        ssh -F ssh-config "$node" "/tmp/target-fw.sh "$fw_duration" "$zigbee_channel" 0" 
}


fw_server()
{
        local node="$1"	
        local fw_duration="$2"
        local zigbee_channel="$3"
        local base
        base="$(dirname "$0")"
        scp -F ssh-config "$base/target-fw.sh" "$node:/tmp"
        ssh -F ssh-config "$node" "/tmp/target-fw.sh "$fw_duration" "$zigbee_channel" 1"
}

die()
{
        (
                [ $# -ne 0 ] && {
                        echo "$@"
                        echo ""
                }
                echo "Usage: $0 [options] [-c|-s] <node> [-f <fw_duration>] [-z <zigbee_channel>]"
                echo ""
                echo "Options:"
                echo " -s <node>            Define the node as a zigbee server"
                echo " -c <node>            Define the node as a zigbee client"
                echo " -f <fw_duration>     Define the duration of the test, defaul value=60"
                echo " -z <zigbee_channel>  Define a zigbee channel between 11-26, default value=15"

        ) >&2
        [ $# -eq 0 ] && exit 0
        exit 1
}

main()
{
	
        local node server_node client_node fw_duration 
        while getopts "hs:c:f:z:" opt; do
            case $opt in
            s) server_node=${OPTARG};;
            c) client_node=${OPTARG};;
            f) fw_duration=${OPTARG};;
            z) zigbee_channel=${OPTARG};;
            h) die;;
            *) die "Invalid arg: $opt";;
            esac
        done
        shift $((OPTIND - 1))
        [ -z "$fw_duration" ] && fw_duration="60"
        [ -z "$zigbee_channel" ] && zigbee_channel="15"
        if [ -n "$server_node" ]; then
                fw_server "$server_node" "$fw_duration" "$zigbee_channel"
        elif [ -n "$client_node" ]; then
                fw_client "$client_node" "$fw_duration" "$zigbee_channel"
        else 
                echo "Missing node"
                return 1
        fi
       
}
main "$@"
exit $?