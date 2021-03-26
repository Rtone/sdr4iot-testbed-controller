#!/bin/bash

set -o pipefail
set -e
set -x

main()
{
        local root="$1"
        local field="$2"

        [ -n "$CONF" ]

        python3 -c "import sys, yaml, os; print(yaml.load(sys.stdin)['$root']['$field'])" < "$CONF"
        return $?
}

main "$@"
exit $?
