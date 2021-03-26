#!/bin/bash

set -o pipefail
set -e
set -x

erase_nrf52_fw()
{
        local node="$1"
        ssh -F ssh-config "$node" "sudo nrfjprog -f nrf52 --eraseall"
        return $?
}

die()
{
        (
                [ $# -ne 0 ] && {
                        echo "$@"
                        echo ""
                }
                echo "Usage: $0 -n <node>"
                echo ""
                echo "Parameters:"
                echo " -n <node> Define nrf52 node to erase"
                
        ) >&2
        [ $# -eq 0 ] && exit 0
        exit 1
}

main()
{
	
        local node
        local err=0
        while getopts "hn:" opt; do
            case $opt in
            n) node=${OPTARG};;
            h) die;;
            *) die "Invalid arg: $opt";;
            esac
        done
        shift $((OPTIND - 1))  
	
	[ -n "$node" ]
        erase_nrf52_fw "$node"
}
main "$@"
exit $?
