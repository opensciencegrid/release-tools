#!/usr/bin/python3

import collections
import getpass
import urllib
import getopt
import json
import sys
import os
import re

from datetime import datetime, timedelta

def usage():
    script = os.path.basename(__file__)
    print(f"Usage: {script} [opensciencegrid/]<REPO>")
    print("")
    print("Options:")
    print("  -u user   dockerhub username")
    print("  -y        don't prompt for confirmation")
    print("  -q        only output errors; implies -y")
    print("")
    print("Environment:")
    print("  HUB_USER:    dockerhub username")
    print("  HUB_PASS:    dockerhub password")
    print("")
    print("If these are omitted, the script will prompt for them.")
    sys.exit()

def parseargs(args):
    try:
        ops, args = getopt.getopt(args, "u:qy")
    except getopt.GetoptError:
        usage()
    if len(args) != 1:
        usage()
    repo, = args
    ops = dict(ops)

    user = ops.get('-u') or os.getenv("HUB_USER")
    pw   = os.getenv("HUB_PASS")
    if not user:
        user = input("dockerhub username: ")
    if not pw:
        pw = getpass.getpass("dockerhub password: ")

    return repo, user, pw, ops

def prompt_user(tags, prune_tags, ops):
    print("The following tags were found; those with a * will be deleted:")
    print("")
    for tag in sorted(tags):
        star = "*" if tag in prune_tags else " "
        print(f"{star} {tag}")

    print("")

    if '-y' not in ops:
        yes = input("Is this OK? (y/[N]) ")
        if yes not in ('y', 'yes'):
            sys.exit()
    print("")

def set_map(fn, seq):
    return set(map(fn, seq))

def set_filter(fn, seq):
    return set(filter(fn, seq))

def authstr(user, passwd):
    from base64 import encodestring
    return encodestring('%s:%s' % (user,passwd)).replace('\n', '')


## unsure about urllib request and response. It was originally
# 'urllib2.request(url)' and 'urllib2.urlopen(req)'
def get_registry_auth_token(repo, user=None, pw=None):
    authurl = "https://auth.docker.io/token"
    scope = f"repository:{repo}:pull,push"
    service = "registry.docker.io"
    url = f"{authurl}?scope={scope}&service={service}"
    req = urllib.request.Request(url)
    if user and pw:
        req.add_header("Authorization", "Basic %s" % authstr(user, pw))
    resp = urllib.request.urlopen(req)
    return json.load(resp)['token']

## same as above
def query_docker_registry(rel_url, auth_token):
    REGISTRY = "https://registry-1.docker.io"
    CONTENT_TYPE = "application/vnd.docker.distribution.manifest.v2+json"
    url = REGISTRY + rel_url
    req = urllib.request.Request(url)
    req.add_header("Accept", CONTENT_TYPE)
    req.add_header("Authorization", f"Bearer {auth_token}")
    resp = urllib.request.urlopen(req)
    return json.load(resp)

def get_tag_manifest(repo, tag, auth_token):
    rel_url = f"/v2/{repo}/manifests/{tag}"
    return query_docker_registry(rel_url, auth_token)

def get_tags(repo, auth_token):
    rel_url = f"/v2/{repo}/tags/list"
    return query_docker_registry(rel_url, auth_token)['tags']

def is_timestamp_tag(tag):
    return re.search(r'^20[0-9]{6}-[0-9]{4}$', tag)

def tag_older_than(days):
    now = datetime.now()
    delta = timedelta(days)
    def check(tag):
        then = datetime.strptime(tag, "%Y%m%d-%H%M")
        return now - then > delta
    return check

def get_3m_old_tags(tags):
    return set_filter(tag_older_than(90), tags)

def get_1y_old_tags(tags):
    return set_filter(tag_older_than(365), tags)

def get_monthly_tags(ts_tags):
    # return the most recent tag for each month
    monthly_buckets = collections.defaultdict(set)
    for tag in ts_tags:
        monthly_buckets[tag[:len("YYYYMM")]].add(tag)
    return set_map(max, monthly_buckets.values())

# braided helper class
class FrenchBread:
    def __init__(self, repo, user=None, passwd=None):
        self.authstr = authstr(user, passwd)
        self.repo = repo = repo if '/' in repo else "opensciencegrid/" + repo
        self.auth_token = get_registry_auth_token(self.repo, user, passwd)

    def get_tag_manifest(self, tag):
        return get_tag_manifest(self.repo, tag, self.auth_token)

    def get_tags(self):
        return get_tags(self.repo, self.auth_token)

    def get_tags_to_prune(self):
        tags = set(self.get_tags())
        ts_tags = set_filter(is_timestamp_tag, tags)
        old_tags1 = get_3m_old_tags(ts_tags)
        old_tags2 = get_1y_old_tags(ts_tags)
        monthly_tags = get_monthly_tags(ts_tags)
        delete_tags1 = (old_tags1 - monthly_tags) | old_tags2
        keep_tags = set(['stable', 'fresh']) & tags
        keep_manifests = list(map(self.get_tag_manifest, keep_tags))
        delete_tags2 = set(
            tag for tag in delete_tags1
            if self.get_tag_manifest(tag) not in keep_manifests
        )
        dontkeep_tags = set(['development']) & tags
        delete_tags3 = delete_tags2 | dontkeep_tags
        return tags, delete_tags3

# ...

def get_jwt_auth_token(user, pw):
    url = "https://hub.docker.com/v2/users/login/"
    req = urllib.request.Request(url)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    req.get_method = lambda : 'POST'
    data = {"username":user, "password":pw}
    resp = urllib.request.urlopen(req, json.dumps(data))
    return json.load(resp)['token']

def delete_tag(repo, tag, jwt_auth_token):
    url = f"https://hub.docker.com/v2/repositories/{repo}/tags/{tag}/"
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json")
    req.add_header("Authorization", "JWT " + jwt_auth_token)
    req.get_method = lambda : 'DELETE'
    resp = urllib.request.urlopen(req)
    return resp

# helper class that taketh away
class RepoMan:
    def __init__(self, repo, user, passwd):
        self.repo = repo = repo if '/' in repo else "opensciencegrid/" + repo
        self.jwt_auth_token = get_jwt_auth_token(user, passwd)

    def delete_tag(self, tag):
        return delete_tag(self.repo, tag, self.jwt_auth_token)

def main(args):
    repo, user, pw, ops = parseargs(args)

    fb = FrenchBread(repo, user, pw)

    tags, prune_tags = fb.get_tags_to_prune()

    if '-q' not in ops:
        prompt_user(tags, prune_tags, ops)

    rman = RepoMan(repo, user, pw)
    for tag in prune_tags:
        if '-q' not in ops:
            print(f"deleting tag {tag} from repo {repo}...")
        rman.delete_tag(tag)

if __name__ == '__main__':
    args = sys.argv[1:]
    main(args)

