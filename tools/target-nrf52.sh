#!/bin/bash

set -o pipefail
set -e
set -x

check_jlink()
{
        JLink_deb="$1"
        local install_package="$2"
        if [ -f /etc/udev/rules.d/99-jlink.rules ];then
                echo "jlink rules are present"
        else
                echo "Adding rules.."
                jlink_rules_path=$(mktemp -d jlink-rules.XXX)
                git clone  --depth 1 https://github.com/kiibohd/manufacturing.git "$jlink_rules_path"
                sudo cp  "$jlink_rules_path"/archpkg/99-jlink.rules /etc/udev/rules.d/
                sudo udevadm control --reload-rules
                sudo udevadm trigger
                rm -rf "$jlink_rules_path" 
        fi  
        [ "$install_package" == "0" ] || sudo dpkg -i "$HOME"/"$JLink_deb" 
        rm -rf "$JLink_deb"
}

check_debugger()
{
        if lsusb | grep -c "SEGGER";
        then
                echo "SEGGER debugger is detected"
        else
                echo "Device is not detected"
                exit 1
        fi
}
init_nrf52()
{
        local JLink_deb="$1"
        local install_package="$2"
        check_debugger
        check_nrf_tools
        check_jlink $JLink_deb $install_package
}

check_nrf_tools()
{
        local nrf_tools_path 
        if command -v nrfjprog;
        then
            echo "nrfjprog is correctly installed"
        else
            echo "Installing nrfjprog..."                   
            nrf_tools_path=$(mktemp -d nrftools.XXX)
            cd $nrf_tools_path
            wget https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/Versions-10-x-x/10-8-0/nRFCommandLineTools1080Linuxamd64tar.gz 
            if sha256sum  nRFCommandLineTools1080Linuxamd64tar.gz | sha256sum -c &>/dev/null;
            then
                    echo "Integrity of nRF command line tools file sucessfully checked"
            else
                    echo "Problems with nRF command line tools version"
                    exit 1
            fi
            tar xvf nRFCommandLineTools1080Linuxamd64tar.gz 
            sudo tar xvf nRF-Command-Line-Tools_10_8_0.tar --directory /opt
            sudo ln -s /opt/nrfjprog/nrfjprog /usr/bin/nrfjprog
            cd $HOME
            rm -rf $nrf_tools_path
            echo "Finished"
        fi	
}

main()
{
        local JLink_deb="$1"
        local install_package="$2"
        init_nrf52 $JLink_deb $install_package
}

main "$@"
exit $?