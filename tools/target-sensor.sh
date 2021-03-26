#!/bin/bash

set -o pipefail
set -e
set -x

die()
{
        (
                [ $# -ne 0 ] && {
                        echo "$@"
                        echo ""
                }
               
        ) >&2
        [ $# -eq 0 ] && exit 0
        exit 1
}

main()
{

        if [ -e "/dev/rm090" ]
        then
                echo "rm090 is detected"
        else
                sudo /usr/local/bin/sensor_powerctrl/sensor_powerctrl.rb ENABLE
        fi        
        i=0
        while [ $i -lt 10 ]; do
                [ -e "/dev/rm090" ] && break
                sleep 1
                i=$((i+1))
        done
        [ -e "/dev/rm090" ] || die "failed to enable…"
}
main "$@"
exit $?
