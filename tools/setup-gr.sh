#!/bin/bash

set -o pipefail
set -e
set -x

get_robot_pos()
{
        local robot="$1"
        local pseudo_yaml x y angle timestamp

        # remove traces
        set +x
        pseudo_yaml="$(curl -s "http://robotcontrol.wilab2.ilabt.iminds.be:5056/Robot/LocationsYaml" -d "filter=$robot")"
        x="$(echo "$pseudo_yaml" | grep -o ':x:.*' | cut -d ' ' -f 2)"
        y="$(echo "$pseudo_yaml" | grep -o ':y:.*' | cut -d ' ' -f 2)"
        angle="$(echo "$pseudo_yaml" | grep -o ':angle:.*' | cut -d ' ' -f 2)"
        timestamp="$(echo "$pseudo_yaml" | grep -o ':time:.*' | cut -d "'" -f 2)"
        # Add \r because ble_dump changes 'tty' mode I think
        echo -e "robot#$robot @$timestamp: $x,$y,$angle°\r"
}

follow_robot()
{
        local robot="$1"

        while true; do
                get_robot_pos "$robot"
                sleep 10
        done
}

at_exit()
{
        local server_job="$1"
        local robot_job="$2"
        local location_job="$3"
        local server_node="$4"
        local ts="$5"
        local experiment_output="$6"	
        local protocol="$7"
        kill "$server_job" || true
        kill "$robot_job" || true
        kill "$location_job" || true
        
        # Download Wireshark archive
        scp -F ssh-config "$server_node:$protocol.cap" "../$server_node-$ts.cap"
        
        # Generate SigMF archive
        ssh -F ssh-config -t "$server_node" "cp $protocol.cap $experiment_output.cap"
        ssh -F ssh-config -t "$server_node" "/tmp/iq_save.py -c $experiment_output.csv -d $experiment_output.sigmf-data"
        ssh -F ssh-config -t "$server_node" "/tmp/tag_iq_data.py -r $experiment_output-position.csv -p $experiment_output.csv -o $experiment_output-tag.csv"
        ssh -F ssh-config -t "$server_node" "/tmp/sigmf_recording.py -c $experiment_output-tag.csv -d $experiment_output.sigmf-data"
        
        # Download SigMF archive
        scp -F ssh-config "$server_node:$experiment_output-tag.sigmf" "../$server_node-$ts-tag.sigmf"
}

rsync_script() # copy code files for ble or zigbee demodulation to the server
{
        local protocol="$1"
        dump="$(CONF=../conf.yml "$(dirname "$0")"/get-field.sh 'user' "${protocol}_dump")"
        [ -n "$dump" ]
        rsync -e 'ssh -F ssh-config' -r --exclude '.git' --exclude '*.iq' --exclude '*.pyc'  --exclude 'build' "$dump" "$server_node:/tmp/"
}

die()
{
        (
                [ $# -ne 0 ] && {
                        echo "$@"
                        echo ""
                }
                echo "Usage: $0 [-s <server_node>] [-m <mobile_node>] [-p <protocol>] [-o] [-e <experiment_details>] [-t <squelsh>]"
                echo ""
                echo "Options:"
                echo "  -s <server_node>            Include server node"
                echo "  -m <mobile_node>            Include mobile node"
                echo "  -p <protocol>               Define the protocol: 'ble' or 'zigbee'"
                echo "  -o                          Enable oot blocks installation"
                echo "  -e <experiment_details>     Define scenario and scene number; example: -e scenario-1 -e scene-2"
                echo "  -t <squelsh>                Define a threshold for radio packet detection"
        ) >&2
        [ $# -eq 0 ] && exit 0
        exit 1
}

main()
{
        local server_node mobile_node protocol oot_boolean scenario scene squelsh experiment_details
        local base usrp robot server_job robot_job location_job ts experiment_output
        local duration
        while getopts "hos:m:p:e:t:d:" opt; do
            case $opt in
            s) server_node=${OPTARG};;
            m) mobile_node=${OPTARG};;
            p) protocol=${OPTARG};;
            o) oot_boolean="true";;
            e) experiment_details="$experiment_details${experiment_details:+ }${OPTARG}";;
            t) squelsh=${OPTARG};;
            d) duration=${OPTARG};;
            h) die;;
            *) die "Invalid arg: $opt";;
            esac
        done
        shift $((OPTIND - 1))
	
        [ -z "$squelsh" ] && squelsh="-93"
        [ -z "$server_node" ] && die "Missing server node"
        [ -z "$mobile_node" ] && mobile_node="mobile0"
        [ -z "$protocol" ] && die "Missing protocol"
        [ -z "$experiment_details" ] && experiment_details='scenario-0 scene-0'
        [ -z "$duration" ] && duration="10"
        for detail in $experiment_details; do
                if [ "$(cut -d'-' -f1 <<<"$detail")" == "scenario" ]; 
                then
                        scenario=$detail
                elif [ "$(cut -d'-' -f1 <<<"$detail")" == "scene" ];
                then   
                        scene=$detail
                else
                        echo "Wrong value "$detail""
                        return 1
                fi
        done

        base="$(dirname "$0")"

        usrp="$("$base"/get-node-field.sh "$server_node" usrp)"
        [ -n "$usrp" ]
        echo "$server_node → usrp#$usrp"

        if [ "$mobile_node" == "mobile0" ]; then
                echo "no robot selected"
                robot="0"
        else
                robot="${mobile_node//mobile/}"
                [ -n "$robot" ]
                echo "$robot → robot#$robot"
        fi

        # GR code and OOT block setup
        if [ "$protocol" == "ble" ];then
		rsync_script "ble"
        elif [ "$protocol" == "zigbee" ];then	
		rsync_script "zigbee"
        else
		echo "wrong value of the protocol"
                return 1
        fi
        if [ "$oot_boolean" == "true" ]; then
        	echo "Installing OOT blocks"
                # Remove CMake
                ssh -F ssh-config "$server_node" "sudo apt-get remove -y cmake && sudo apt-get purge -y cmake"
                
                # Install latest version
                ssh -F ssh-config "$server_node" "sudo apt-get install build-essential"
                ssh -F ssh-config "$server_node" "wget http://www.cmake.org/files/v3.18/cmake-3.18.0.tar.gz"
                ssh -F ssh-config "$server_node" "tar xf cmake-3.18.0.tar.gz"
                ssh -F ssh-config "$server_node" "cd cmake-3.18.0 && ./configure && make"
                
                #ssh -F ssh-config "$server_node" "cp -R /groups/wall2-ilabt-iminds-be/sdr4iot/cmake-3.18.0/ ./"
                ssh -F ssh-config "$server_node" "cd cmake-3.18.0 && sudo make install"
                
                scp -F ssh-config "$base/target-gr-oot.sh" "$server_node:/tmp"
                ssh -F ssh-config "$server_node" "sudo /tmp/target-gr-oot.sh  \"foo\"" # configure oot blocks for wireshark connector(foo) and packet decoding(oqpsk_dsss)
                
                # Zigbee Only
                ssh -F ssh-config "$server_node" "sudo /tmp/target-gr-oot.sh  \"oqpsk_dsss\"  \"CFO_estimator\"" 
                ssh -F ssh-config "$server_node" "sudo /tmp/target-gr-oot.sh  \"ieee802-15-4\"" 
        else
                echo "No need to install OOT blocks"
        fi
        trap 'kill $(jobs -p)' EXIT

        # exec
        ssh -F ssh-config -t "$server_node" "killall ${protocol}_dump.py || true"
        follow_robot "$robot" | ts | tee "../$server_node-$ts-robot.log" &
        robot_job=$!
        ts="$(date +%Y-%m-%d_%H-%M-%S)"
        experiment_output="/groups/wall2-ilabt-iminds-be/sdr4iot/$protocol/$scenario/$scene/$server_node-$mobile_node-$ts"
        ssh -F ssh-config -t "$server_node" "rm $protocol.cap || true"
        ssh -F ssh-config -t "$server_node" "chmod +x /tmp/*.py"
        ssh -F ssh-config -t "$server_node" "mkdir -p $experiment_output"
        ssh -F ssh-config -t "$server_node" "/tmp/${protocol}_dump.py -o $protocol.cap -t $squelsh -i $experiment_output.sigmf-data -l $duration | ts | tee  $experiment_output.log" | tee "../$server_node-$ts.log" &
        server_job=$!
        ssh -F ssh-config -t "$server_node" "/tmp/get_robot_position.py -r $robot -o $experiment_output-position.csv" &
        location_job=$!
        
        echo "Capture duration : $duration"
        echo "Total duration : $(($duration+10))" # We add 10 seconds because GNURadio does not start the capture instantly
        
        # Waiting for xxx_dump.py to be finished, by using 'Head' block in GNURadio to limit samples
        sleep $(($duration+10))
        
        at_exit $server_job $robot_job $location_job $server_node $ts $experiment_output $protocol
}

main "$@"
exit $?
