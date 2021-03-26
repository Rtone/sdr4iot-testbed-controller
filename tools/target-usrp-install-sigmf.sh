#!/bin/bash

set -o pipefail
set -e
set -x

main()
{
        if command -v pip3 &>/dev/null; then
                echo "pip3 found"
        else
                sudo apt update
                sudo apt install -y python3-pip
        fi
        
        if pip3 show sigmf &>/dev/null;
        then
		echo "sigmf is already installed"
        else
		echo "Installing sigmf"
		sudo pip3 install --upgrade pip
		sudo pip3 install sigmf # For sigmf archive
        fi

}

main "$@"
exit $?
