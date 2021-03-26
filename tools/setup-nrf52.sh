#!/bin/bash

set -o pipefail
set -e
set -x

main()
{
        local node="$1"
        local base
        base="$(dirname "$0")"
        local install_package  # Check if there are needs or not to install the pakage
        if ! ssh -F ssh-config "$node" "dpkg -l | grep -q jlink";
        then
		jlinkFileName="JLink_Linux_V686a_x86_64.deb"
		ssh -F ssh-config "$node" "cp /groups/wall2-ilabt-iminds-be/sdr4iot/JLink_Linux_V686a_x86_64.deb ~/JLink_Linux_V686a_x86_64.deb"
        else
                echo "JLink package already exists in $node"
                install_package="0"
        fi        
        scp -F ssh-config "$base/target-nrf52.sh" "$node:/tmp"
        ssh -F ssh-config "$node" "/tmp/target-nrf52.sh "$jlinkFileName" $install_package" 
}

main "$@"
exit $?
