#!/bin/sh
# verify.sh <checkpoint-dir> <list>: succeed only when every file in <list> (sha256sum format, paths
# relative to <checkpoint-dir>) has its recorded SHA-256 and <checkpoint-dir> holds no other file
# (base-agent-0.6b#2). POSIX sh and busybox, so the Dockerfile runs it as is.
set -eu
dir=$1
list=$2
test -f "$list" || { echo "no checksum list $list" >&2; exit 1; }
grep -q . "$list" || { echo "checksum list $list is empty" >&2; exit 1; }
if grep -v -E '^[0-9a-f]{64}  [A-Za-z0-9._/-]+$' "$list" | grep -q .; then
  echo "checksum list $list has a malformed line" >&2
  exit 1
fi
cd "$dir"
sha256sum -c "$list"
files=$(find . -type f | wc -l)
listed=$(grep -c . "$list")
if [ "$files" -ne "$listed" ]; then
  echo "$dir holds $files files, but $list lists $listed" >&2
  exit 1
fi
