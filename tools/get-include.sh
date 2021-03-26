#!/bin/bash

set -o pipefail
set -e

main()
{
        python3 -c "import sys, yaml, os; print(' '.join([n for n in yaml.load(sys.stdin)['include']]))" < ../conf.yml
        return $?
}

main "$@"
exit $?
