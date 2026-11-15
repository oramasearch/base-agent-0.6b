# base-agent-0.6b — the Orama base model as a model image

[`Dockerfile`](Dockerfile) packs one published version of the base agent checkpoint
([`OramaSearch/base-agent-0.6b`](https://huggingface.co/OramaSearch/base-agent-0.6b), private;
model card [zetta `docs/agent/cards/models/base-agent.md`](https://github.com/oramasearch/zetta/blob/dev/docs/agent/cards/models/base-agent.md))
into the private image `oramasearch/base-agent-0.6b:<version>`, for example `:v16`.

**Why it exists** ([lake#246](https://github.com/oramasearch/lake/issues/246),
[lake#799](https://github.com/oramasearch/lake/issues/799)): a native agent created in lake without
a model runs on the base model inside its workspace Zetta. The Orama operator gives every workspace
Zetta this image as `spec.models[{name: base-agent}]`; an init container copies `/model` to
`/data/models/base-agent` on the workspace volume before the node starts, and lake points native
agents at that path. Workspace namespaces deny egress by default, so the checkpoint arrives as an
image the kubelet pulls with the workspace's pull Secret, not as a download from the pod. The
operator side is orama-operator's `docs/zetta-models.md`.

## The contract

- `/model/` holds the checkpoint files: `config.json`, the weights (`model.safetensors`, or
  `model.safetensors.index.json` and its shards), and the tokenizer (`tokenizer.json`, or
  `vocab.json` + `merges.txt`), plus whatever else the version folder has. The build fails if the
  required ones are missing.
- **The files are exactly the recorded version** (base-agent-0.6b#2). [`checksums/`](checksums/README.md)
  holds, per version, the Hub commit it is taken from (`<version>.revision`) and the SHA-256 of
  every file (`<version>.sha256`). The build runs [`checksums/verify.sh`](checksums/verify.sh) and
  fails on a changed, missing or extra file.
- The base image is pinned by digest (`busybox:1.37@sha256:...`), so a moved tag cannot change it.
- `/bin/sh` exists (busybox), because the operator's copy script runs in this image.
- Every file is readable by uid 10001, the Zetta node's user.
- **A tag is never moved.** The operator replaces the copy on a volume only when the image string
  changes, so a new checkpoint is a new tag (`v17`), and the operator's default
  (`lakeDefaultBaseModelImage` in `internal/controller/lake_defaults.go`) moves with it, rolled dev,
  testing, staging, prod.

## Building a version

The context is a directory with two folders: `checkpoint/`, the version's files, and `checksums/`,
copied from this repository. Take the files from a zetta checkout's local checkpoint first (zetta's
root `CLAUDE.md`, *Checkpoints live in `data/checkpoints/`*), and from the Hub only when they are not
on disk. Either way the build checks them against `checksums/<version>.sha256`, so a local copy that
differs from the recorded version in any file fails the build; download it from the Hub instead.

```sh
version=v16
ctx=$(mktemp -d)
cp -R checksums "$ctx/checksums"
# local: the same files the Hub's v16/ folder holds
cp -R <zetta>/data/checkpoints/base-agent-0.6b-interaction-v16 "$ctx/checkpoint"
# or from the Hub at the pinned revision (private; needs `hf auth login` with access to OramaSearch)
#   hf download OramaSearch/base-agent-0.6b --revision "$(cat checksums/$version.revision)" \
#     --include "$version/*" --local-dir "$ctx/hub"
#   mv "$ctx/hub/$version" "$ctx/checkpoint"
# optional, before the build: the same check the Dockerfile runs
sh checksums/verify.sh "$ctx/checkpoint" "$ctx/checksums/$version.sha256"
```

Images are built on the cluster BuildKit, never with Docker on the Mac (liquid-bridge decision 33;
the `liquid-dev` skill has the lane): `buildctl build --frontend dockerfile.v0 --local
context="$ctx" --local dockerfile=. --opt platform=linux/amd64 --opt build-arg:VERSION=v16 --output
type=image,name=docker.io/oramasearch/base-agent-0.6b:v16,push=true`.

**A new version** adds `checksums/<version>.revision` and `checksums/<version>.sha256` first, as
[`checksums/README.md`](checksums/README.md) says, and builds with `build-arg:VERSION=<version>`.

`sh tests/verify_test.sh` tests the check: a changed byte, a missing or extra file and a malformed
list all fail, every recorded version has a pinned revision, and the base image is pinned by digest.

**Before the first push, create the Docker Hub repository private** (`POST /v2/repositories/` with
`"is_private": true`): a first push creates it public. Afterwards an anonymous
`curl -s -o /dev/null -w '%{http_code}' https://hub.docker.com/v2/repositories/oramasearch/base-agent-0.6b/`
must answer `404` (umbrella `CLAUDE.md`, *Every service is its own private repo*).

## Size

The fp32 checkpoint is about 2.2 GB, so the image is too, and it is copied onto every workspace
volume (lake's default is 5 GiB). A bf16 copy of the same weights is half that, and the engine
loads `BF16` safetensors (zetta `src/core/compute/safetensors.cpp`), widening them to fp32 in memory, so
it is a possible later step that changes the volume cost, not the memory one.

## Where it came from

Moved out of zetta's `images/base-agent/` ([zetta#1344](https://github.com/oramasearch/zetta/pull/1344))
on 2026-10-23: every image lives in its own private repository (umbrella `CLAUDE.md`, *Every service
is its own private repo, with its own private image*). Pinned by
[zetta-bridge](https://github.com/oramasearch/zetta-bridge) as `modules/base-agent-0.6b`.
