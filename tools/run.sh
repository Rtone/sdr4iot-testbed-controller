#!/bin/bash

set -o pipefail

JFED_PATH="${JFED_PATH:-$(dirname "$0")/jfed}"
TEMPLATE_PATH="${TEMPLATE_PATH:-$(dirname "$0")/../templates}"

build_yml()
{
        local conf="$1"
        local jfed_conf="$2"

        mkdir -p "$(dirname "$jfed_conf")" || die "Cannot create dir for $jfed_conf"

        j2 "$TEMPLATE_PATH"/run.yml.j2 "$conf" > "$jfed_conf"
        return $?
}

build_ansible()
{
        local conf="$1"
        local ansible_dir="$2"
        local rc=0

        mkdir -p "$ansible_dir" || die "Cannot create $ansible_dir"

        for f in "$TEMPLATE_PATH/ansible/"*; do
                local base j2
                base="$(basename "$f")"
                j2="$(basename "$f" .j2)"
                if [ "$base" != "$j2" ]; then
                        # template: use j2
                        j2 "$f" "$conf" > "$ansible_dir/$j2"
                        [ $? -ne 0 ] && rc=1
                else
                        # simple file
                        cp "$f" "$ansible_dir/$base" || rc=1
                fi
        done
        return $rc
}

run_jfed()
{
        local conf="$1"
        local log="$2"

        mkdir -p "$(dirname "$log")" || die "Cannot create dir for log: $log"

        java -jar "$JFED_PATH"/jfed_cli/experimenter-cli2.jar --action "$conf" --debug 2>&1 | ts | tee -a "$log"
        [ $? -ne 0 ] && return 1
        if grep -q "Ready, because ExperimentState is READY" "$log"; then
                return 0
        fi
        echo "Output does not seem to be ok"
        return 1
}

die()
{
        (
                [ $# -ne 0 ] && {
                        echo "$@"
                        echo ""
                }
                echo "Usage: $0 [-f <conf>]+ [-i <include>]* [-x <exclude>]* [-n]"
                echo ""
                echo "Options:"
                echo "  -f <conf>   Use configuration (yml file in conf/). Could be repeated"
                echo "  -i <node>   Include <node> (could be repeated)"
                echo "  -x <node>   Exclude <node> (could be repeated)"
                echo "  -n          Dry-run: does not run jfed-cli"
        ) >&2
        [ $# -eq 0 ] && exit 0
        exit 1
}

main()
{
        local conf ts include conf exclude dry_run delay base

        while getopts "hnf:i:xd" opt; do
                case $opt in
                f) conf="$conf${conf:+ }$OPTARG";;
                i) include="$include${include:+ }$OPTARG";;
                x) exclude="$exclude${exclude:+ }$OPTARG";;
                d) delay=1;;
                n) dry_run="1";;
                d) [ -n "$OPTARG" ] && delay="$OPTARG";;
                h) die;;
                *) die "Invalid arg: $opt";;
                esac
        done
        shift $((OPTIND - 1))


        [ -z "$conf" ] && die "Missing configuration file"
        for c in $conf; do
                [ ! -f "$c" ] && die "$c is not a file"
        done
        [ $# -ne 0  ] && die "Extra args: $*"

        # Find for USER_PEM and USER_PEM_PASSWORD in conf
        for c in $conf; do
                local value
                value="$(CONF="$c" "$(dirname "$0")"/get-field.sh 'user' 'pem')"
                [ -n "$value" ] && [ -z "$USER_PEM" ] && {
                        export USER_PEM="$value"
                }
                value="$(CONF="$c" "$(dirname "$0")"/get-field.sh 'user' 'pem_password')"
                [ -n "$value" ] && [ -z "$USER_PEM_PASSWORD" ] && {
                        export USER_PEM_PASSWORD="$value"
                }
        done

        [ -n "$USER_PEM" ] || echo "WARNING: no \$USER_PEM. Will use user.pem"
        [ -n "$USER_PEM_PASSWORD" ] || die "ERROR: no \$USER_PEM_PASSWORD"

        [ -n "$delay" ] && {
                # Delay to have different:
                # - "timestamps" for directory
                # - slice
                delay="${include//[!0-9]/}"
                if [ -z "$delay" ] || [ "$delay" -gt 100 ]; then
                        die "Invalid delay: $delay (from include: $include)"
                fi
                echo "Sleeping $delay seconds (from include: $include)"
                sleep "$delay"
        }

        #SLICE="${SLICE:-$(printf "%x" "$(date +%s)" | rev | cut -b -7 | rev)}"
        SLICE="${SLICE:-$(date +%s | rev | cut -b -7 | rev)}"
        ts="$(date +%Y-%m-%d-%H%M%S)"

        base="run/$ts"
        for c in $conf; do
                base="$base-$(basename "$c")"
        done
        for node in $include; do
                base="$base-$node"
        done
        for node in $exclude; do
                base="$base-x-$node"
        done
        mkdir -p "$base" || die "Cannot create $base for this run"
        echo "Using $base for this run"
        full_conf="$base/conf.yml"
        for c in $conf; do
                cat "$c" >> "$full_conf"
        done
        echo "include: [ ${include/ /, } ]" >> "$full_conf"
        echo "exclude: [ ${exclude/ /, } ]" >> "$full_conf"


        local jfed_conf="$base/run.yml"
        local ansible_dir="$base/ansible"

        export ANSIBLE_PATH="$ansible_dir"
        export SLICE
        build_ansible "$full_conf" "$ansible_dir" || die "Cannot create $ansible_dir from $full_conf"
        build_yml "$full_conf"  "$jfed_conf" || die "Cannot create $jfed_conf from $full_conf"

        [ -z "$dry_run" ] && {
                echo "Starting jFed (note: it could take up to 10 minutes)"
                run_jfed "$jfed_conf" "$base/run.log" || die "Cannot run $jfed_conf"
        }

        echo "Ok: ready to execute ansible commands in $ansible_dir"

}

main "$@"
exit $?
