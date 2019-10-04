#!/bin/bash

REGISTRY=https://registry-1.docker.io
REPO_OWNER=opensciencegrid
REPO_PROJECT=osg-wn
REPOSITORY=$REPO_OWNER/$REPO_PROJECT
TAG_OLD=fresh
TAG_NEW=stable
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

