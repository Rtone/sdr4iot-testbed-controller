#!/bin/bash

URL="http://jfed.ilabt.imec.be/downloads/stable/jar/jfed_cli.tar.gz"


main()
{
        local tgz dest
        set -o pipefail
        set -e
        set -x

        local url="$1"
        [ -z "$url" ] && url="$URL"
        tgz="jfed-cli.tar.gz"
        curl -L "$url" -o "$tgz"
        dest="$(dirname "$0")/jfed"
        mkdir -p "$dest"
        tar -C "$dest" -xvzf "$tgz"
        rm "$tgz"
}

main "$@"
exit $?
