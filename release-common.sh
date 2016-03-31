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
    # Runs command and appends the command string to a rescue file
    # Expects double quoted string (be sure to escape chars that you don't want
    # evaluated by bash when being echoed to the rescue file e.g. '\$1' or '\"')
    # cmd=`sed s'/\*/\\\*/ <<< $1` # hack to prevent * from being shell expanded
    cmd=$1
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "$cmd"
    else
        $cmd
        echo $cmd >> "$original_cmd.rescue"
    fi
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

DRY_RUN=0
versions=()
original_cmd=$0

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

