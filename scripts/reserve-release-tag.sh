#!/usr/bin/env bash
set -euo pipefail
FLAVOR=${1:?Usage: reserve-release-tag.sh open-source|closed-source}
case "$FLAVOR" in open-source|closed-source) ;; *) exit 1;; esac
TAG="${FLAVOR}-$(date +%Y%m%d)-${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"
printf 'tag=%s\n' "$TAG" >> "${GITHUB_OUTPUT:?}"
REPO=${GITHUB_REPOSITORY:?}
if existing=$(gh api "repos/$REPO/git/ref/tags/$TAG" --jq .object.sha 2>/dev/null); then
  test "$existing" = "${GITHUB_SHA:?}"
else
  # Reserve while the event commit is still the branch head. Creating a tag
  # on an older commit with changed workflows can require workflows:write,
  # which GITHUB_TOKEN cannot obtain. Publishing an existing tag avoids this.
  gh api --method POST "repos/$REPO/git/refs" \
    -f ref="refs/tags/$TAG" -f sha="${GITHUB_SHA:?}" >/dev/null
fi
echo "已预留 Release 标签：$TAG"
