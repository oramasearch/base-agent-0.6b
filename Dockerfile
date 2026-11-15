# syntax=docker/dockerfile:1.7
#
# The Orama base model as a model image (lake#246): the checkpoint under /model and a POSIX
# shell, the contract of orama-operator's OramaZettaCluster spec.models (docs/zetta-models.md).
# Every Lake workspace Zetta copies it to /data/models/base-agent before it starts, and a native
# agent created without a model loads it from there.
#
# The build context holds two directories: checkpoint/, with the files of one published version of
# OramaSearch/base-agent-0.6b, and checksums/, this repository's recorded SHA-256 of every file of
# each version (README.md says how to fetch and lay them out). Only checkpoint/ goes in the image.
#
# busybox is pinned by digest (the 1.37 index on Docker Hub, 2026-11-14), so a moved tag cannot
# change the image (base-agent-0.6b#2).
FROM busybox:1.37@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec
# The version whose recorded checksums the checkpoint must match, for example v16.
ARG VERSION=v16
COPY --chmod=0755 checkpoint/ /model/
# A checkpoint the engine cannot load must not become an image: the native loader needs the
# config and the weights, and the BPE tokenizer needs tokenizer.json or vocab.json + merges.txt.
RUN test -f /model/config.json \
 && { test -f /model/model.safetensors || test -f /model/model.safetensors.index.json; } \
 && { test -f /model/tokenizer.json || { test -f /model/vocab.json && test -f /model/merges.txt; }; }
# A checkpoint that is not exactly the recorded version must not become an image either: every
# file's SHA-256 must match checksums/<version>.sha256, and /model may hold no file the list does
# not name (base-agent-0.6b#2). The checksums are mounted for this step only, not copied in.
RUN --mount=type=bind,source=checksums,target=/checksums \
    sh /checksums/verify.sh /model "/checksums/${VERSION}.sha256"
USER 10001
