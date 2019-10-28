# Release Tools

See our Release documentation under the
[OSG Technology docs](https://opensciencegrid.org/technology/release/cut-sw-release/).

## Notes on specific tools:

### `dockerhub-prune-tags.py`

For [SOFTWARE-3844](https://opensciencegrid.atlassian.net/browse/SOFTWARE-3844),
we have a tool to cleanup OSG Software docker images based on our policy:

    - Weekly timestamped image tags will be kept for at least three months
    - After three months, monthly timestamped image tags will be kept for at least one year

The tool `dockerhub-prune-tags.py` untags images with only a timestamp tag
(that is, without also being tagged as `fresh` or `stable`) according to the
above rules.

```
Usage: dockerhub-prune-tags.py [opensciencegrid/]<REPO>

Options:
  -u user   dockerhub username
  -y        don't prompt for confirmation
  -q        only output errors; implies -y

HUB_USER and HUB_PASS may be set in the environment
```

### `dockerhub-tag-fresh-to-stable.sh`

For [SOFTWARE-3843](https://opensciencegrid.atlassian.net/browse/SOFTWARE-3843),
we have a tool to script tagging OSG Software docker images as `stable`.

The tool can be used to 'promote' the image currently tagged as `fresh`,
or any timestamped image, in the form `<YYYYMMDD-HHMM>`.

Optionally, a destination tag (other than `stable`) may be provided.

```
usage: dockerhub-tag-fresh-to-stable.sh REPO OLD_TAG [NEW_TAG]

arguments:
  REPO:     '<owner>/<name>' eg 'opensciencegrid/frontier-squid'
            (<owner> defaults to 'opensciencegrid' if omitted)
  OLD_TAG:  Either 'fresh' or <YYYYMMDD-HHMM>
  NEW_TAG:  Defaults to 'stable'

Environment:
  user:     dockerhub username
  pass:     dockerhub password

If these are omitted, the script will prompt for them.
```
