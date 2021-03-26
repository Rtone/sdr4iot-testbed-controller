#!/bin/bash

set -o pipefail
set -e
set -x


setup_usrp()
{
        local node="$1"
        
        local usrp base
        base="$(dirname "$0")"
        usrp="$("$base"/get-node-field.sh "$node" "usrp")"

        [ -n "$usrp" ]
        echo "$node → usrp#$usrp"
        scp -F ssh-config "$base/target-usrp-install-sigmf.sh" "$node:/tmp"
        scp -F ssh-config "$base/target-usrp.sh" "$node:/tmp"
        ssh -F ssh-config "$node" "sudo /tmp/target-usrp.sh" "$usrp"
}

main()
{
        local base
        base="$(dirname "$0")"

        [ $# -eq 0 ] && {
                set "$("$base"/get-include.sh)"
        }
        local err=0
        for node in "$@"; do
                setup_usrp "$node" || err=1
        done
        return $err
}

main "$@"
exit $?
