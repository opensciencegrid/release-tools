#!/bin/bash
set -e

usage () {
  echo "usage: $(basename "$0") REPO OLD_TAG [NEW_TAG]"
  echo
  echo "arguments:"
  echo "  REPO:     '<owner>/<name>' eg 'opensciencegrid/frontier-squid'"
  echo "            (<owner> defaults to 'opensciencegrid' if omitted)"
  echo "  OLD_TAG:  Either 'fresh' or <YYYYMMDD-HHMM>"
  echo "  NEW_TAG:  Defaults to 'stable'"
  echo
  echo "Environment:"
  echo "  user:     dockerhub username"
  echo "  pass:     dockerhub password"
  echo
  echo "If these are omitted, the script will prompt for them."
  exit
}

[[ $2 ]] || usage
REPOSITORY=$1
TAG_OLD=$2
TAG_NEW=${3:-stable}

[[ $REPOSITORY = */* ]] || REPOSITORY=opensciencegrid/$REPOSITORY
case $TAG_OLD in
  fresh | 20[1-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9] ) ;; # OK
  * ) usage ;;
esac

REGISTRY=https://registry-1.docker.io
CONTENT_TYPE="application/vnd.docker.distribution.manifest.v2+json"

getvar () {
  read -p "dockerhub $1? " "$1"
}

[[ $user ]] || getvar user
[[ $pass ]] || getvar pass

TOKEN=$(
  authurl=https://auth.docker.io/token
  scope=repository:${REPOSITORY}:pull,push
  service=registry.docker.io
  url="$authurl?scope=$scope&service=$service"
  curl -s -u "$user:$pass" "$url" | jq -r .token
)

MANIFEST=$(
  curl -s \
       -H "Accept: ${CONTENT_TYPE}" \
       -H "Authorization: Bearer $TOKEN" \
       "${REGISTRY}/v2/${REPOSITORY}/manifests/${TAG_OLD}"
)

curl -X PUT \
     -H "Content-Type: ${CONTENT_TYPE}" \
     -H "Authorization: Bearer $TOKEN" \
     -d "${MANIFEST}" \
     "${REGISTRY}/v2/${REPOSITORY}/manifests/${TAG_NEW}"

