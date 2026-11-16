#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check that the release version in VERSION is documented.

    python3 tools/test-version.py      # exit 1, naming what is missing, if a check fails

VERSION holds the repository's release version (X.Y.Z), the one name of the Git tag, the GitHub
release and the image's release tag. The checks read it from there, so no number is repeated:
- docs/releases/vX.Y.Z.md exists and its title names vX.Y.Z;
- docs/releases/README.md links it;
- README.md names the release.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main() -> int:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        print(f"VERSION is not X.Y.Z: {version!r}")
        return 1
    tag = f"v{version}"
    failures = []
    notes = ROOT / "docs" / "releases" / f"{tag}.md"
    if not notes.is_file():
        failures.append(f"{notes.relative_to(ROOT)} is missing")
    elif tag not in notes.read_text(encoding="utf-8").splitlines()[0]:
        failures.append(f"the title of {notes.relative_to(ROOT)} does not name {tag}")
    index = ROOT / "docs" / "releases" / "README.md"
    if not index.is_file() or f"({tag}.md)" not in index.read_text(encoding="utf-8"):
        failures.append(f"docs/releases/README.md does not link {tag}.md")
    if f"docs/releases/{tag}.md" not in (ROOT / "README.md").read_text(encoding="utf-8"):
        failures.append(f"README.md does not name docs/releases/{tag}.md")
    for failure in failures:
        print(failure)
    if not failures:
        print(f"{tag}: notes, index and README agree")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
