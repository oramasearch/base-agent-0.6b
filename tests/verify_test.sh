#!/bin/sh
# Tests for checksums/verify.sh and the recorded checksum files (base-agent-0.6b#2).
# Run: sh tests/verify_test.sh   (needs sha256sum: coreutils or busybox)
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
verify="$root/checksums/verify.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
expect_ok() { if sh "$verify" "$2" "$3" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }
expect_refused() { if sh "$verify" "$2" "$3" >/dev/null 2>&1; then fail "$1"; else pass "$1"; fi; }

fresh() {
  rm -rf "$work/checkpoint"
  mkdir -p "$work/checkpoint"
  printf '{"model_type": "qwen3"}\n' > "$work/checkpoint/config.json"
  printf 'weights' > "$work/checkpoint/model.safetensors"
  printf '{}\n' > "$work/checkpoint/tokenizer.json"
  (cd "$work/checkpoint" && sha256sum config.json model.safetensors tokenizer.json) > "$work/list"
}

fresh
expect_ok "a checkpoint matching its list passes" "$work/checkpoint" "$work/list"

fresh
printf 'Weights' > "$work/checkpoint/model.safetensors"
expect_refused "one changed byte in the weights fails" "$work/checkpoint" "$work/list"

fresh
rm "$work/checkpoint/tokenizer.json"
expect_refused "a missing file fails" "$work/checkpoint" "$work/list"

fresh
printf 'extra' > "$work/checkpoint/extra.bin"
expect_refused "a file the list does not name fails" "$work/checkpoint" "$work/list"

fresh
: > "$work/empty"
expect_refused "an empty list fails" "$work/checkpoint" "$work/empty"
expect_refused "a missing list fails" "$work/checkpoint" "$work/nothing"

fresh
printf 'not-a-hash  config.json\n' >> "$work/list"
expect_refused "a malformed line fails" "$work/checkpoint" "$work/list"

# Every recorded version has a revision (a 40-hex Hub commit) and well-formed checksums that name
# the files the Dockerfile requires.
for list in "$root"/checksums/v*.sha256; do
  version=$(basename "$list" .sha256)
  revision="$root/checksums/$version.revision"
  if grep -q -E '^[0-9a-f]{40}$' "$revision" 2>/dev/null; then
    pass "$version has a pinned revision"
  else
    fail "$version has a pinned revision"
  fi
  if grep -v -E '^[0-9a-f]{64}  [A-Za-z0-9._/-]+$' "$list" | grep -q .; then
    fail "$version checksums are well formed"
  else
    pass "$version checksums are well formed"
  fi
  if grep -q '  config.json$' "$list" \
     && grep -q -E '  model\.safetensors(\.index\.json)?$' "$list"; then
    pass "$version lists the config and the weights"
  else
    fail "$version lists the config and the weights"
  fi
done

if grep -q -E '^FROM busybox:[^@]+@sha256:[0-9a-f]{64}$' "$root/Dockerfile"; then
  pass "the base image is pinned by digest"
else
  fail "the base image is pinned by digest"
fi

[ "$failures" -eq 0 ] || { echo "$failures failed"; exit 1; }
