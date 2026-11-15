# base-agent-0.6b — the Orama base model as a model image

[`Dockerfile`](Dockerfile) packs one published version of the base agent checkpoint
([`OramaSearch/base-agent-0.6b`](https://huggingface.co/OramaSearch/base-agent-0.6b) on Hugging Face;
model card [zetta `docs/agent/cards/models/base-agent.md`](https://github.com/oramasearch/zetta/blob/dev/docs/agent/cards/models/base-agent.md))
into the image `oramasearch/base-agent-0.6b:<version>`, for example `:v16`.

**Why it exists:** a native agent created in lake without
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
- `/bin/sh` exists (busybox), because the operator's copy script runs in this image. The base is
  `busybox:1.37` pinned by its multi-platform index digest (`sha256:a7dbc319…`, lake#1003), so a
  moved tag cannot change it; moving it is a reviewed change of the digest.
- Every file is readable by uid 10001, the Zetta node's user.
- **A tag is never moved.** The operator replaces the copy on a volume only when the image string
  changes, so a new checkpoint is a new tag (`v17`), and the operator's default
  (`lakeDefaultBaseModelImage` in `internal/controller/lake_defaults.go`) moves with it.

## Building a version

The context is a directory with one folder, `checkpoint/`. Take the files from a zetta checkout's
local checkpoint (`data/checkpoints/`), or download the version from the Hub:

```sh
ctx=$(mktemp -d)
# local: the same files the Hub's v16/ folder holds
cp -R <zetta>/data/checkpoints/base-agent-0.6b-interaction-v16 "$ctx/checkpoint"
# or from the Hub
#   hf download OramaSearch/base-agent-0.6b --include 'v16/*' --local-dir "$ctx/hub"
#   mv "$ctx/hub/v16" "$ctx/checkpoint"
```

Then build with any BuildKit builder, from this repository with `$ctx` as the context:

```sh
docker buildx build --platform linux/amd64 -f Dockerfile -t <registry>/base-agent-0.6b:v16 --push "$ctx"
```

## Size

The fp32 checkpoint is about 2.2 GB, so the image is too, and it is copied onto every workspace
volume (lake's default is 5 GiB). A bf16 copy of the same weights is half that, and the engine
loads `BF16` safetensors (zetta `src/core/compute/safetensors.cpp`), widening them to fp32 in memory, so
it is a possible later step that changes the volume cost, not the memory one.

## License of the weights

The checkpoint is a fine-tune of [Qwen/Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B), which
its authors release under the Apache License 2.0; that license and its notice apply to the base
weights this image carries.

## Where it came from

Moved out of zetta's `images/base-agent/` on 2026-10-23, so the image has a repository of its own.
Moved out of zetta's `images/base-agent/` ([zetta#1344](https://github.com/oramasearch/zetta/pull/1344))
on 2026-10-23: every image lives in its own private repository (umbrella `CLAUDE.md`, *Every service
is its own private repo, with its own private image*). Pinned by
[zetta-bridge](https://github.com/oramasearch/zetta-bridge) as `modules/base-agent-0.6b`.

## License

This repository's files are MIT, see [LICENSE](LICENSE). The model weights in the image are a
fine-tune of Qwen3-0.6B and are under the Apache License 2.0; see [NOTICE](NOTICE). Third-party components and their licenses are in
[THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES). Contributions are welcome under the Developer
Certificate of Origin; see [CONTRIBUTING.md](CONTRIBUTING.md).
