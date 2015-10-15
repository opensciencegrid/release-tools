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
DRY_RUN=

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
        -n|--dry-run)
            DRY_RUN='echo $'
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
if [[ $majorver = 3.2 ]]; then
    dvers=(el5 el6)
elif [[ $majorver = 3.3 ]]; then
    dvers+=(el6 el7)
else
    die 'Unrecognized major version. Acceptable release series are 3.2.x and 3.3.x'
fi

branches=($majorver)
if [ $upcoming -eq 1 ]; then
    branches+=('upcoming')
fi
