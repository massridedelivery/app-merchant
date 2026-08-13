#!/usr/bin/env bash
#
# Increment the build number (the `+N` suffix) in pubspec.yaml.
# `version: 1.0.0+2` -> `version: 1.0.0+3`. Leaves the change in the working
# tree for you to commit.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import re
p = "pubspec.yaml"
s = open(p, encoding="utf-8").read()
m = re.search(r'^version:\s*(\S+?)\+(\d+)\s*$', s, re.M)
if not m:
    raise SystemExit("ERROR: could not find 'version: <name>+<build>' in pubspec.yaml")
name, build = m.group(1), int(m.group(2))
nxt = build + 1
s = s[:m.start()] + f"version: {name}+{nxt}" + s[m.end():]
open(p, "w", encoding="utf-8").write(s)
print(f"build number: {name}+{build} -> {name}+{nxt}")
PY
