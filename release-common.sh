#!/bin/bash

die () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "usage: `basename $0` [options] <VERSION 1> [<VERSION 2>...<VERSION N>]"
    echo "Options:"
    echo -e "\t-h, --help\tPrint this message"
    echo -e "\t-d, --dry-run\tPrint the commands that would be run"
}

print_header () {
    echo -e "\033[1;33m$1\033[0m"
}

osg_release () {
    osgversion=$1
    sed -r 's/\.[0-9]+$//' <<< $osgversion
}

osg_dvers () {
    osgversion=$1
    branch=$(osg_release $osgversion)
    if [[ $branch == '3.2' ]]; then
        echo el5 el6
    elif [[ $branch == '3.3' || $branch == 'upcoming' ]]; then
        echo el6 el7
    fi
}

run_cmd () {
    # Runs command(s) (accepting pipes and redirection!) and appends the command
    # string to a rescue file if successful. Prints cmd to stdout if user
    # specifies -d/--dry-run. Expects double quoted string (be sure to escape
    # chars that you don't want evaluated by bash when being echoed to the rescue
    # file e.g. '\$1' or '\"')
    cmd=$1
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "$cmd"
    else
        grep "$cmd" $rescue_file > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            eval $cmd
            if [[ $? -eq 0 ]]; then
                echo "$cmd" >> $rescue_file
            else
                exit 1
            fi
        fi
    fi
}

cleanup_on_success () {
    rm $rescue_file
}

pkg_dist () {
    osgversion=$1
    dver=$2

    if [[ $osgversion == 'upcoming' ]]; then
        echo "osgup.$dver"
    else
        branch=$(osg_release $osgversion)
        echo "osg$(sed 's/\.//' <<< $branch).$dver"
    fi
}

if [ $# -lt 1 ]; then
    usage
    die
fi

########
# MAIN #
########

DRY_RUN=0
versions=()
original_cmd=$0
rescue_file=$original_cmd.rescue

while [ $# -ne 0 ];
do
    case $1 in
        -h|--help)
            usage
            die
            ;;
        -d|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -*)
            usage
            die "unknown option: $1"
            ;;
        *)
            if [[ $1 =~ ^3\.[2-3]+\.[0-9]+$ || $1 == 'upcoming' ]]; then
                versions+=($1)
                shift
            else
                usage
                die "unknown parameter: $1"
            fi
    esac
done

if [[ ${versions[@]} == 'upcoming' ]]; then
    usage
    die "Upcoming promotions must be accompanied by at least one version number"
fi

[ -e $rescue_file ] && print_header "Found rescue file, picking up after the last successful command...\n" || touch $rescue_file
