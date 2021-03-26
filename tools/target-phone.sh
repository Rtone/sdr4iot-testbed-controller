#!/bin/bash

set -o pipefail
set -e
set -x

init()
{
    if [ -d "/android/android-sdk-linux/platform-tools" ]
    then
	    echo "Android SDK manager exists"
    else
        mkdir -p /android/android-sdk-linux
        cd /android/android-sdk-linux
        wget https://dl.google.com/android/repository/platform-tools_r29.0.5-linux.zip
        unzip platform-tools_r29.0.5-linux.zip
        rm platform-tools_r29.0.5-linux.zip
    fi    
    cd /android/android-sdk-linux/platform-tools
    ./adb devices
    ./adb kill-server
    cp /share/upload/LTE/android/keys/adbkey ~/.android/
    cp /share/upload/LTE/android/keys/adbkey.pub ~/.android/
    ./adb devices | tee /dev/stderr | grep -E '\<device\>'
    if ./adb shell settings get global bluetooth_on; 
    then
        echo "Bluetooth is not activated"
        ./adb shell settings put global bluetooth_on 1
        ./adb shell am start -a android.bluetooth.adapter.action.REQUEST_ENABLE
        ./adb shell input tap 1761 831
    fi
}

install_apk()
{
    local apk="$1"
    local app="$2"
    # abs path (since will be root)
    apk="$(readlink -f "$apk")"

    /android/android-sdk-linux/platform-tools/adb uninstall "$app"  # ignore result
    /android/android-sdk-linux/platform-tools/adb install "$apk" | tee /dev/stderr | grep 'Success'

}

grant_perms()
{
    local app="$1"
    local perm="$2"

    # Grant BLE permissiong
    sudo ./adb shell pm grant "$app" "$perm"
}

start_activity()
{
    local activity="$1"
    cd /android/android-sdk-linux/platform-tools
    sudo ./adb shell am start -n "$activity" | tee /dev/stderr | grep -vi 'Error'
}

dump_ble_mac()
{
    /android/android-sdk-linux/platform-tools/adb shell settings get secure bluetooth_address
}

main()
{
    local apk="$1"
    local app="$2"
    local activity="$3"

    init
    install_apk "$apk" "$app"
    dump_ble_mac
    #grant_perms "$app" "$perms"
    start_activity "$app/.$activity"

    return 0
}

main "$@"
exit $?
