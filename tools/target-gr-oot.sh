#!/bin/bash

set -o pipefail
set -e
set -x

main()
{
        if [ $# -ne 0 ];
        then
                for oot_block in "$@";do
                        cd /tmp/gr-"$oot_block"
                        sudo rm -rf build
                        sudo mkdir build
                        cd build
                        cmake -D CMAKE_INSTALL_PREFIX=/usr/local  ../
                        make
                        sudo make install
                        sudo ldconfig
                        
                done  
        fi
}
main "$@"
exit $?