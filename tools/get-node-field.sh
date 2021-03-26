#!/bin/bash

set -o pipefail
set -e
set -x

main()
{
        local node="$1"
        local field="$2"

        python3 -c "import sys, yaml, os; print([n for n in yaml.load(sys.stdin)['nodes'] if n['name'] == '$node'][0]['$field'])" < ../conf.yml
        return $?
}

main "$@"
exit $?
