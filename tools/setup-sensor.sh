#!/bin/bash

set -o pipefail
set -e
set -x

main()
{
        local node="$1"
        local base
        base="$(dirname "$0")"
        scp -F ssh-config "$base/target-sensor.sh" "$node:/tmp"
        ssh -F ssh-config "$node" "sudo /tmp/target-sensor.sh"
        
        # Upload hex file 
        if ! ssh -F ssh-config "$node" "sudo /share/upload/sensor/ibcn-f5x-tos-bsl --invert-reset --swap-reset-test -c /dev/rm090 -r -e -I -5 -p /share/upload/sensor/apps/rm090/wsnbridge/wsnbridge.ihex"; 
        then
                ssh -F ssh-config "$node" "sudo /usr/local/bin/sensor_powerctrl/sensor_powerctrl.rb DISABLE"
	        ssh -F ssh-config "$node" "sudo /usr/local/bin/sensor_powerctrl/sensor_powerctrl.rb ENABLE "
	        ssh -F ssh-config "$node" "sudo /share/upload/sensor/ibcn-f5x-tos-bsl --invert-reset --swap-reset-test -c /dev/rm090 -r -e -I -5 -p /share/upload/sensor/apps/rm090/wsnbridge/wsnbridge.ihex"
        else
	        echo 'Device successfully reset'
        fi
}

main "$@"
exit $?
