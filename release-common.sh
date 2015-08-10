#!/bin/bash

die () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "usage: `basename $0` [options] VERSION"
    echo "Options:"
    echo -e "\t-h, --help\tPrint this message"
    echo -e "\t-u, --upcoming\tAlso populate upcoming pre-release"
}

if [ $# -lt 1 ]; then
    usage
    die
fi

upcoming=0

while [ $# -ne 0 ];
do
    case $1 in
        -h|--help)
            usage
            die
            ;;
        -u|--upcoming)
            upcoming=1
            shift
            ;;
        -*)
            usage
            die "unknown option: $1"
            ;;
        *)
            if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                version=$1
                shift
            else
                usage
                die "unkown parameter: $1"
            fi
    esac
done

majorver=`sed -r 's/\.[0-9]+$//' <<< $version`
osgver="osg`sed 's/\.//' <<< $majorver`"

# Handle distro version differences between OSG versions
dvers=(el6 el7)
if [ $majorver == '3.2' ]; then
    dvers+=(el5)
fi

branches=($majorver)
if [ $upcoming -eq 1 ]; then
    branches+=('upcoming')
fi
