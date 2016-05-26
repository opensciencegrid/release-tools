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

DRY_RUN=''
versions=()

while [ $# -ne 0 ];
do
    case $1 in
        -h|--help)
            usage
            die
            ;;
        -d|--dry-run)
            DRY_RUN='echo $'
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
