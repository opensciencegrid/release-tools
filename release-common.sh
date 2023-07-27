#!/bin/bash

die () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "usage: $script_name [options] <RELEASE DATE> <VERSION 1> [<VERSION 2>...<VERSION N>]"
    echo "Options:"
    echo -e "\t-d REVISION, --data REVISION\tSpecify the REVISION of the data-only release"
    echo -e "\t-n, --dry-run\t\t\tPrint the commands that would be run"
    echo -e "\t-h, --help\t\t\tPrint this message"
}

print_header () {
    if [[ -t 1 ]]; then
        echo -e "\033[1;33m$1\033[0m"
    else
        echo -e "$1"
    fi
}

print_header_with_line () {
    print_header "$1"
    print_header "$(tr '[:print:]' = <<< "$1")"
}

osg_dvers () {
    branch=$1
    case $branch in
      3.5 | 3.5-upcoming ) echo el7 el8 ;;
      3.6 | 3.6-upcoming ) echo el7 el8 el9 ;;
      23-main | 23-upcoming ) echo el8 el9 ;;
    esac
}

is_rel_ver () {
    [[ $1 =~ ^(3\.[56]|[2-9][0-9])(-upcoming)?$ ]]
}

add_branch_to_ver () {
    # OSG 23+ should always have either -main or -upcoming appended
    # OSG 3.6 may have either -upcoming or nothing
    if [[ $1 =~ ^([2-9][0-9])$ ]]; then 
        echo $1-main
    else
        echo $1
    fi
}

is_date_tag () {
    [[ $1 =~ ^[0-9]{6}$ ]]
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
        echo "$cmd" >> $rescue_file
    else
        grep -F "$cmd" $rescue_file > /dev/null 2>&1
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

check_file_transfer_rc () {
    # Exit script if files fail to copy over so we can use the rescue file
    # mechanism to resend the files
    if [ $1 -ne 0 ]; then
        echo -e "\033[1;31mFailed to copy release notes to AFS. Re-run $script_name\033[0m"
        exit 1
    fi
}

check_for_command () {
    # check to see if command in $1 is available
    # returns 0 if command is in path and is executable, 1 otherwise
    cmd_path=`command -v $1`
    if [[ $? -ne 0 ]]
    then
        return 1
    fi
    # check to see if command is executable
    if [[ -x "$cmd_path" ]]
    then
        return 0
    fi
    echo "$1 is in PATH but is not executable"
    return 1
}

check_for_and_add_command () {
    # check for command in path, try to add it in by 
    # adding . to PATH  
    # returns 1 on failure, 0 on success
    check_for_command $1
    if [[ $? -ne 0 ]];
    then
        PATH=$PATH:.
        check_for_command $1
        if [[ $? -ne 0 ]];
        then
           return 1
        fi
    fi
    return 0
}

check_for_osg_koji () {
    # check to see if osg-koji is available
    # exit with exit code 1 if not
    check_for_command osg-koji
    if [[ $? -ne 0 ]];
    then
        echo "osg-koji not in PATH, please fix"
        exit 1
    fi
}

detect_rescue_file () {
    rescue_file=`pwd`/$script_name.rescue
    [ -e $rescue_file ] && print_header "Found rescue file, picking up after the last successful command...\n" \
            || touch $rescue_file
}

cleanup_on_success () {
    rm $rescue_file
}

pkgs_to_release () {
    branch=$1
    dver=$2
    awk "/^RPMs.*osg-$branch-$dver-testing/ {flag=1;next} /^[[:space:]]*$/ { flag=0 } flag { print }" release-list | grep -v =======
}

ver_tag () {
    # Return major-version.yymmdd
    echo $1.$date_tag | sed 's/-[a-z]\+//'
}

########
# MAIN #
########

DRY_RUN=0
DATA=0
date_tag=
versions=()
script_name=$(basename $0)

if [ $# -lt 1 ]; then
    usage
    die
fi

while [ $# -ne 0 ];
do
    case $1 in
        -h|--help)
            usage
            die
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -d|--data)
            shift
            DATA=$1
            if ! [[ $DATA =~ ^[2-9]$ ]]; then
                die "Unexpected revision number: $DATA"
            fi
            shift
            ;;
        -*)
            usage
            die "unknown option: $1"
            ;;
        *)
            if is_rel_ver "$1"; then
                versions+=($(add_branch_to_ver $1))
                shift
            elif is_date_tag "$1" && [ -z $date_tag ]; then
                date_tag=$1
                shift
            elif is_date_tag "$1" && [ -n $date_tag ]; then
                die "Date tag already entered: $date_tag"
            else
                usage
                die "unknown parameter: $1"
            fi
    esac
done

