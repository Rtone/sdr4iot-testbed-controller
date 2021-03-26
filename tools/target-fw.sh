#!/bin/bash

set -o pipefail
set -e
set -x


main()
{
        local fw_duration="$1"
        local zigbee_channel="$2"
        local node_type="$3" # 0 if client node, 1 if server node
        local fw_process bridge_process
        local start_time
        start_time=$(date +'%s')
        if [ "$node_type" == "0" ]; # client node
        then
                sudo /share/upload/sensor/apps/rm090/wsnbridge/wsnbridge dev=/dev/rm090 server=localhost:2010 fixedChannel="$zigbee_channel" confLocalPanID=2010 confLocalShortAddr=301 prefixLocalShortAddr='yes' prefixLocalPanID='yes' prefixSenderShortAddr='yes' dumpFrames2Log=yes &
                bridge_process=$!
                iperf -C -u -s -p 2010 -i 1 &
                fw_process=$!
        elif [ "$node_type" == "1" ]; # server node
        then        
                sudo /share/upload/sensor/apps/rm090/wsnbridge/wsnbridge dev=/dev/rm090 fixedChannel="$zigbee_channel" prefixLocalShortAddr='yes' prefixLocalPanID='yes' prefixSenderShortAddr='yes' prefixLocalShortAddr='yes' prefixLocalPanID='yes' prefixSenderShortAddr='yes' dumpFrames2Log=no &
                bridge_process=$!
                iperf -C -u -c localhost -b 1e6 -l 250B -t "$fw_duration" -i 1 -p 2010 &
                fw_process=$!
        else
                echo "Wrong value"
                return 1
        fi
        sleep $((fw_duration+10))
        if [ "$(($(date +'%s') - $start_time))" -gt "$fw_duration" ]; # to check if elapsed time reaches the required time duration (defined in options)for the firmware experiment
        then
                echo "Exiting..."
                sudo kill "$bridge_process" || true
                sudo kill "$fw_process" || true
                exit 1
        fi
        wait                                                                                                                                                                                                                                                                                                  
}
main "$@"
exit $?