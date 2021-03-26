#!/bin/bash

set -o pipefail
set -e
set -x

setup_phone()
{
        local node="$1"

        local apk activity base
        base="$(dirname "$0")"

        apk="$("$base/get-node-field.sh" "$node" "apk")"
        app="$("$base/get-node-field.sh" "$node" "app")"
        activity="$("$base/get-node-field.sh" "$node" "activity")"
        [ -n "$apk" ]
        [ -n "$app" ]
        [ -n "$activity" ]
        [ -f "$apk" ] || {
                # find apk in root/apks/
                [ -f "$base/../apks/$apk" ]
                apk="$base/../apks/$apk"
        }
        echo "$node → $apk / $app / $activity"
        scp -F ssh-config "$(dirname "$0")/"target-phone.sh "$node:/tmp"
        scp -F ssh-config "$apk" "$node:/tmp"
        ssh -F ssh-config "$node" "sudo /tmp/target-phone.sh" "/tmp/$(basename "$apk")" "$app" "$activity"
        #ssh -F ssh-config "$node" "/android/android-sdk-linux/platform-tools/adb shell input tap 1540 840"
}


main()
{
        local  base err
        base="$(dirname "$0")"

        [ $# -eq 0 ] && {
                set "$("$base"/get-include.sh)"
        }

        # Check that id_rsa exists. If not, run jfed-gui with an experiment,
        # generate ansible files and extract id_rsa and id_rsa.pub files and
        # put them in /templates/ansible (and here)
        [ -f "id_rsa" ]
        # make ssh happy with 'secret' key
        chmod 600 id_rsa

        err=0
        for node in "$@"; do
                setup_phone "$node" || err=1
        done
        return $err
}

main "$@"
exit $?
