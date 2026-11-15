# Checksums of each published version

One pair of files per version of [`OramaSearch/base-agent-0.6b`](https://huggingface.co/OramaSearch/base-agent-0.6b)
that this repository packs (base-agent-0.6b#2):

- `<version>.revision`: the Hub commit the version folder is taken from. Downloads pin it with
  `--revision`, so a later push to the Hub repository never changes what a build gets.
- `<version>.sha256`: the SHA-256 of every file in the version folder, in `sha256sum` format with
  paths relative to `/model`. The [`Dockerfile`](../Dockerfile) runs `sha256sum -c` on it and
  refuses a checkpoint with a changed, missing or extra file.

## v16

Revision `3f6eb0850f3c9ed1743c56b9aff80ba8ddb73084` (the Hub's `main` on 2026-11-14), folder `v16/`.

Where each hash comes from:

- `model.safetensors` and `tokenizer.json` are LFS files: their SHA-256 is the one the Hub API
  publishes for them (`model_info(..., files_metadata=True)`, `siblings[].lfs.sha256`). The weights
  were not downloaded to record it.
- The other six files are small non-LFS files, for which the Hub publishes only a git blob id.
  They were downloaded at the pinned revision, their git blob ids were checked against the Hub's
  (`git hash-object`), and their SHA-256 was computed from them.

A new version adds its own `<version>.revision` and `<version>.sha256` the same way; a version's
files are never edited once its image is pushed (*A tag is never moved*).
