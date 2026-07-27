#!/usr/bin/env python3
# Print the newest Ubuntu LTS release with published cloud images, e.g.
# "26.04". Empty output means "nothing detected" and is not an error; a
# non-zero exit means detection itself is broken (network error, HTTP
# error, or a page that no longer matches the expected shape) and must be
# reported by the caller, never swallowed. A failure must NEVER print a
# plausible-but-wrong version -- the version is only printed after every
# step below has succeeded.
#
# Source of truth: https://cloud-images.ubuntu.com/releases/
# Fetched and confirmed by hand (2026-07-26): the directory is a plain
# Apache-style autoindex, one row per line, numeric AND codename
# directories both present, each with a trailing description, e.g.
#   <a href="22.04/">22.04/</a>   ... Ubuntu Server 22.04 LTS (Jammy Jellyfish) released builds
#   <a href="24.10/">24.10/</a>   ... Ubuntu Server 24.10 (Oracular Oriole) released builds [END OF LIFE - for reference only]
#   <a href="26.04/">26.04/</a>   ... Ubuntu Server 26.04 LTS (Resolute Raccoon) released builds
# This builder only tracks LTS releases (all.release.conf currently has
# 22.04/24.04/26.04, never an interim 24.10/25.04/25.10 -- confirmed
# against every conf under conf/*.conf), so the pattern below requires the
# literal " LTS" marker on the SAME line as the numeric href; an interim
# release's line has no such marker and is excluded without an explicit
# denylist. Confirmed present at .../releases/26.04/release/ :
#   ubuntu-26.04-server-cloudimg-amd64.img -- the exact asset name shape
#   this builder's VM_VHD_LINK downloads for every release.
#
# stdlib only (urllib.request, re, sys, os) -- no external dependencies.

import os
import re
import sys
import urllib.request

URL = "https://cloud-images.ubuntu.com/releases/"
TIMEOUT = 60
USER_AGENT = "anyvm-org-upstream-watcher/1.0"

# The whole match must stay on one line: href="<ver>/" ... LTS, with no
# newline in between (each directory row is a single line on this page).
PATTERN = re.compile(r'href="(\d+\.\d+)/"[^\n]*\bLTS\b')


def resolve_natural_key():
    """Return the engine's own natural_key, or fail loudly.

    watch.yml clones base-builder INTO the builder repo root, so at
    detection time it sits at "base-builder/" (relative to this hook's
    cwd, the builder repo root). A local checkout instead has it as a
    sibling, "../base-builder". Try both, in that order.

    There is deliberately NO local fallback copy. Ordering must be the
    single rule the engine uses -- a per-hook duplicate would have to be
    kept in sync by hand across every builder and would drift silently,
    and a hook that ranks versions differently from watch.py is worse
    than one that refuses to run. Both real contexts (CI and a local
    sibling checkout) always provide base-builder, so an ImportError here
    means the environment is wrong: report it as broken detection rather
    than guessing an order.
    """
    for candidate in ("base-builder", os.path.join("..", "base-builder")):
        if not os.path.isdir(candidate):
            continue
        path = os.path.abspath(candidate)
        if path not in sys.path:
            sys.path.insert(0, path)
        try:
            import gendata
            return gendata.natural_key
        except ImportError:
            continue
    raise ImportError(
        "base-builder/gendata.py not importable from %s; expected it at "
        "./base-builder (CI) or ../base-builder (local checkout)"
        % os.getcwd())


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", "replace")


def main():
    try:
        key = resolve_natural_key()
    except ImportError as e:
        sys.stderr.write("upstream_check: %s\n" % e)
        return 1
    try:
        html = fetch(URL)
    except Exception as e:
        sys.stderr.write("upstream_check: fetch of %s failed: %s\n"
                         % (URL, e))
        return 1
    versions = PATTERN.findall(html)
    if not versions:
        sys.stderr.write("upstream_check: no LTS release directory found "
                         "in %s; page shape may have changed\n" % URL)
        return 1
    newest = sorted(set(versions), key=key)[-1]
    print(newest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
